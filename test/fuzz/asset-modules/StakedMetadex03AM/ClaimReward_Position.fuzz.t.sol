/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ILeafVoter } from "../../../utils/fixtures/metadex03/interfaces/ILeafVoter.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test, StakingAM } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "ClaimReward" function (position rewards) of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ClaimReward_Position_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_claimReward_Position_NotOwner(address owner, address randomAddress, uint96 positionId)
        public
    {
        // Given: The position is owned by another address than the caller.
        vm.assume(owner != randomAddress);
        stakedMetadex03AM.setOwnerOfPositionId(owner, positionId);

        // When: randomAddress claims the reward of the position.
        // Then: It reverts.
        vm.startPrank(randomAddress);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedMetadex03AM.claimReward(positionId);
        vm.stopPrank();
    }

    function testFuzz_Revert_claimReward_Position_PenaltyWindowOpen(
        uint128 amount,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 blocksPassed
    ) public {
        // Given: A position minted in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);
        amount = uint128(bound(amount, 1, type(uint128).max));
        uint256 positionId = _mintPosition(users.accountOwner, amount);

        // And: The penalty window of its own deposit is still open.
        blocksPassed = bound(blocksPassed, 0, minStakeBlocks - 1);
        vm.roll(block.number + blocksPassed);

        // When: The owner claims the reward of the position.
        // Then: It reverts.
        vm.prank(users.accountOwner);
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.claimReward(positionId);
    }

    function testFuzz_Revert_claimReward_ChainSuspended_NonZeroEarned(uint128 amount, uint256 emissions) public {
        // Given: A position with earned emissions, above what the gauge's rewardPerToken floors away.
        vm.assume(amount != 0);
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        assertGt(metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId)), 0);

        // And: The chain is suspended.
        setChainSuspended(true);

        // When: The owner claims the reward of the position.
        // Then: It reverts.
        vm.prank(users.accountOwner);
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03AM.claimReward(positionId);
    }

    function testFuzz_Success_claimReward_Position_NonZeroReward(
        address account_,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public {
        // Given: A non-zero position, owned by account_.
        vm.assume(account_ != address(0));
        vm.assume(account_ != address(stakedMetadex03AM));
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        stakedMetadex03AM.setOwnerOfPositionId(account_, positionId);

        // And: The pool is allowed in the Registry, with its gauge onboarded on the Asset Module.
        _addGauge();

        // And: A valid asset and position state is persisted.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: The credited reward plus what the staker of the position earned is non-zero.
        uint256 reward = uint256(positionState.lastRewardPosition) + assetState.currentRewardGlobal;
        vm.assume(reward > 0);

        // When: account_ claims the reward of the position.
        // Then: The reward is paid out.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.RewardPaid(positionId, address(stakedMetadex03AM.REWARD_TOKEN()), uint128(reward));
        uint256 rewards = stakedMetadex03AM.claimReward(positionId);
        vm.stopPrank();

        // And: The claimed reward is returned.
        assertEq(rewards, reward);

        // And: The Asset Module keeps only its resting balance.
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), surplusState.lastRewardBalance);

        // And: The position state is updated.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(metadex03Pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked);
        assertEq(newPositionState.lastRewardPerTokenPosition, positionState.lastRewardPerTokenPosition);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: The asset state is untouched.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);
    }

    function testFuzz_Success_claimReward_Position_ZeroReward(
        address account_,
        uint96 positionId,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public {
        // Given: A non-zero position, owned by account_.
        vm.assume(account_ != address(0));
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        stakedMetadex03AM.setOwnerOfPositionId(account_, positionId);

        // And: The pool is allowed in the Registry, with its gauge onboarded on the Asset Module.
        _addGauge();

        // And: A valid asset and position state, without credited rewards or staker emissions.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        positionState.lastRewardPosition = 0;
        assetState.currentRewardGlobal = 0;

        // And: The state is persisted.
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // When: account_ claims the reward of the position.
        vm.startPrank(account_);
        uint256 rewards = stakedMetadex03AM.claimReward(positionId);
        vm.stopPrank();

        // Then: No claimed rewards are returned.
        assertEq(rewards, 0);

        // And: account_ did not receive reward tokens.
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(account_), 0);

        // And: The position state is updated.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(metadex03Pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked);
        assertEq(newPositionState.lastRewardPerTokenPosition, positionState.lastRewardPerTokenPosition);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: The asset state is untouched.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked);
    }

    function testFuzz_Success_claimReward_Position_DustMintOfOtherPosition(
        uint128 amount,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate
    ) public {
        // Given: A position minted in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);
        amount = uint128(bound(amount, 1, type(uint128).max - 1));
        uint256 positionId = _mintPosition(users.accountOwner, amount);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: Emissions accrue, above what a penalty of a single pip rounds away.
        emissions = bound(emissions, MAX_PIPS + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 net = metadex03Gauge.earned(staker);

        // And: The penalty window of the position has passed.
        vm.roll(block.number + minStakeBlocks);
        uint256 gross = metadex03Gauge.earned(staker);
        assertGt(gross, net);
        uint256 depositBlock = metadex03Gauge.depositBlock(staker);

        // And: Another user mints a dust position in the same gauge.
        _mintPosition(users.unprivilegedAddress, 1);

        // When: The owner claims the reward of the position.
        vm.prank(users.accountOwner);
        uint256 rewards = stakedMetadex03AM.claimReward(positionId);

        // Then: The full reward is paid, the dust mint opened no window on its staker.
        assertEq(rewards, gross);
        assertEq(ERC20(receiptToken).balanceOf(users.accountOwner), gross);
        assertEq(metadex03Gauge.depositBlock(staker), depositBlock);
    }

    function testFuzz_Success_claimReward_Position_IncreaseOfOtherPosition(
        uint128 amount,
        uint128 amountOther,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate
    ) public {
        // Given: A position minted in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);
        amount = uint128(bound(amount, 1, type(uint128).max / 3));
        uint256 positionId = _mintPosition(users.accountOwner, amount);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: Emissions accrue, above what a penalty of a single pip rounds away.
        emissions = bound(emissions, MAX_PIPS + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 net = metadex03Gauge.earned(staker);

        // And: Another user mints a position in the gauge, both fitting the uint128 totalStaked.
        amountOther = uint128(bound(amountOther, 1, type(uint128).max / 3));
        uint256 positionIdOther = _mintPosition(users.liquidityProvider, amountOther);

        // And: The penalty windows of both positions have passed.
        vm.roll(block.number + minStakeBlocks);
        uint256 gross = metadex03Gauge.earned(staker);
        assertGt(gross, net);
        uint256 depositBlock = metadex03Gauge.depositBlock(staker);

        // And: The other position increases its liquidity.
        _increasePosition(users.liquidityProvider, positionIdOther, amountOther);

        // When: The owner claims the reward of the position.
        vm.prank(users.accountOwner);
        uint256 rewards = stakedMetadex03AM.claimReward(positionId);

        // Then: The full reward is paid, the other deposit opened no window on its staker.
        assertEq(rewards, gross);
        assertEq(ERC20(receiptToken).balanceOf(users.accountOwner), gross);
        assertEq(metadex03Gauge.depositBlock(staker), depositBlock);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function testFuzz_Success_claimReward_Position_PenaltyActive_PaysStakerNetEarned(
        uint128 amountFirst,
        uint128 amountSecond,
        uint128 amountIncrease,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        uint256 minStakeBlocks,
        uint256 penaltyRate
    ) public {
        // Given: Three stakes and a dust stake that together fit the uint128 totalStaked.
        amountFirst = uint128(bound(amountFirst, 1, type(uint128).max / 4));
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max / 4));
        amountIncrease = uint128(bound(amountIncrease, 1, type(uint128).max / 4));

        // And: Both emission legs fit in the gauge's uint128 reward share.
        emissionsFirst = bound(emissionsFirst, 0, type(uint128).max / 2);
        emissionsSecond = bound(emissionsSecond, 0, type(uint128).max - emissionsFirst);

        // And: A gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);

        // And: Two users mint a position each.
        uint256[] memory positionIds = new uint256[](3);
        positionIds[0] = _mintPosition(users.accountOwner, amountFirst);
        positionIds[1] = _mintPosition(users.liquidityProvider, amountSecond);
        assertSolvent(positionIds);

        // And: Emissions accrue and the penalty windows of both deposits close.
        addEmissionsToGauge(address(metadex03Gauge), emissionsFirst);
        vm.roll(vm.getBlockNumber() + minStakeBlocks);

        // And: A third user mints a dust position.
        positionIds[2] = _mintPosition(users.unprivilegedAddress, 1);
        assertSolvent(positionIds);

        // And: The first position increases its liquidity, which credits what its staker earned.
        uint256 creditedFirst = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIds[0]));
        _increasePosition(users.accountOwner, positionIds[0], amountIncrease);
        assertSolvent(positionIds);

        // And: More emissions accrue while the first and the third position have open windows.
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);

        // When: The second position claims.
        uint256 expected = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIds[1]));
        vm.prank(users.liquidityProvider);
        stakedMetadex03AM.claimReward(positionIds[1]);

        // Then: The net earned emissions of its own staker are paid.
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), expected);
        assertSolvent(positionIds);

        // When: The first position claims once its own window closed.
        vm.roll(vm.getBlockNumber() + minStakeBlocks);
        expected = creditedFirst + metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIds[0]));
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionIds[0]);

        // Then: Its credited reward and the net earned emissions of its own staker are paid.
        assertEq(ERC20(receiptToken).balanceOf(users.accountOwner), expected);
        assertSolvent(positionIds);

        // When: The dust position decreases its full liquidity.
        expected = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIds[2]));
        vm.prank(users.unprivilegedAddress);
        stakedMetadex03AM.decreaseLiquidity(positionIds[2], 1);

        // Then: The net earned emissions of its own staker are paid.
        assertEq(ERC20(receiptToken).balanceOf(users.unprivilegedAddress), expected);
        assertSolvent(positionIds);
    }
}
