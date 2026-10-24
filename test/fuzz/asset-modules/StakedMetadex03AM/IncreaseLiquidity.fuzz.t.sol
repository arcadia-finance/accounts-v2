/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ILeafVoter } from "../../../utils/fixtures/metadex03/interfaces/ILeafVoter.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test, StakingAM } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "increaseLiquidity" of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract IncreaseLiquidity_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_increaseLiquidity_ZeroAmount(uint96 positionId) public {
        // Given: Any positionId.

        // When: Calling increaseLiquidity() for a zero amount.
        // Then: It reverts.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakedMetadex03AM.increaseLiquidity(positionId, 0);
    }

    function testFuzz_Revert_increaseLiquidity_NotOwner(
        address account_,
        address randomAddress,
        uint128 amount,
        uint96 positionId
    ) public canReceiveERC721(account_) {
        // Given: A non-zero positionId, owned by another address than the Account.
        vm.assume(account_ != randomAddress);
        vm.assume(account_ != address(0));
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        stakedMetadex03AM.setOwnerOfPositionId(randomAddress, positionId);

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: The Account holds a non-zero LP balance, approved to the Asset Module.
        amount = uint128(bound(amount, 1, type(uint128).max));
        deal(address(metadex03Pool), account_, amount);
        vm.prank(account_);
        metadex03Pool.approve(address(stakedMetadex03AM), amount);

        // When: Calling increaseLiquidity() for that positionId.
        // Then: It reverts.
        vm.startPrank(account_);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedMetadex03AM.increaseLiquidity(positionId, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_increaseLiquidity_PenaltyWindowOpen(
        uint128 amount,
        uint128 amountSecond,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 blocksPassed
    ) public {
        // Given: A position staked in a gauge whose GaugeFactory penalises an early unstake.
        amount = uint128(bound(amount, 1, type(uint128).max - 1));
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);
        uint256 positionId = _mintPosition(users.accountOwner, amount);

        // And: The penalty window of its own deposit is still open.
        blocksPassed = bound(blocksPassed, 0, minStakeBlocks - 1);
        vm.roll(block.number + blocksPassed);

        // And: The owner holds more LP, which with the staked amount fits the uint128 totalStaked.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));
        deal(address(metadex03Pool), users.accountOwner, amountSecond);
        vm.startPrank(users.accountOwner);
        metadex03Pool.approve(address(stakedMetadex03AM), amountSecond);

        // When: The position increases its liquidity.
        // Then: It reverts.
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.increaseLiquidity(positionId, amountSecond);
        vm.stopPrank();
    }

    function testFuzz_Revert_increaseLiquidity_ChainSuspended_NonZeroEarned(
        uint128 amount,
        uint128 amountSecond,
        uint256 emissions
    ) public {
        // Given: A position with emissions above the gauge's flooring per 1e18 of stake, so its earned is non-zero.
        vm.assume(amount != 0);
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);

        // And: The chain is suspended.
        setChainSuspended(true);

        // And: The owner holds a non-zero LP balance, approved to the Asset Module.
        vm.assume(amountSecond != 0);
        deal(address(metadex03Pool), users.accountOwner, amountSecond);
        vm.startPrank(users.accountOwner);
        metadex03Pool.approve(address(stakedMetadex03AM), amountSecond);

        // When: The position increases its liquidity, its deposit claiming the non-zero earned emissions first.
        // Then: It reverts.
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03AM.increaseLiquidity(positionId, amountSecond);
        vm.stopPrank();
    }

    function testFuzz_Success_increaseLiquidity(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint96 positionId,
        uint128 amount,
        address account_
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));
        {
            // And: The metadex03Pool and its gauge are onboarded.
            _addGauge();
            vm.assume(account_ != address(metadex03Pool));
            vm.assume(account_ != metadex03Pool.poolFees());
            vm.assume(account_ != address(metadex03Gauge));
            vm.assume(account_ != address(leafVoter));

            // And: Valid state.
            givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);

            // And: State is persisted for a non-zero position.
            positionId = uint96(bound(positionId, 1, type(uint96).max));
            setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

            // And: Owner of positionId is Account.
            stakedMetadex03AM.setOwnerOfPositionId(account_, positionId);

            // And: Amount staked is non-zero and the updated totalStaked still fits a uint128.
            vm.assume(assetState.totalStaked < type(uint128).max);
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            // And: Account has a balance of metadex03Pool LP tokens, approved to the Asset Module.
            deal(address(metadex03Pool), account_, amount);
            vm.prank(account_);
            metadex03Pool.approve(address(stakedMetadex03AM), amount);
        }

        // When: A user is increasing liquidity via the stakedMetadex03AM.
        // Then: The liquidity is increased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(positionId, address(metadex03Pool), amount);
        stakedMetadex03AM.increaseLiquidity(positionId, amount);

        // And: Assets should have been staked through the staker of the position.
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionId)), positionState.amountStaked + amount);

        // And: Position state should be updated correctly, crediting what its staker earned.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(metadex03Pool));
        assertEq(newPositionState.amountStaked, positionState.amountStaked + amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, positionState.lastRewardPerTokenPosition);
        assertEq(newPositionState.lastRewardPosition, positionState.lastRewardPosition + assetState.currentRewardGlobal);

        // And: Asset values should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
        assertEq(
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)),
            surplusState.lastRewardBalance + positionState.lastRewardPosition + assetState.currentRewardGlobal
        );
    }

    function testFuzz_Success_increaseLiquidity_ChainSuspended_ZeroEarned(uint128 amount, uint128 amountSecond) public {
        // Given: A position without earned emissions.
        amount = uint128(bound(amount, 1, type(uint128).max - 1));
        uint256 positionId = _initPositionWithEarned(amount, 0);

        // And: The chain is suspended.
        setChainSuspended(true);

        // And: The owner holds more LP, which with the staked amount fits the uint128 totalStaked.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));

        // When: The position increases its liquidity, its zero-earned claim not calling mintEmissions.
        _increasePosition(users.accountOwner, positionId, amountSecond);

        // Then: The liquidity is increased.
        (, uint128 amountStaked,,) = stakedMetadex03AM.positionState(positionId);
        assertEq(amountStaked, amount + amountSecond);
    }

    function testFuzz_Success_increaseLiquidity_DonationNotCredited(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint128 amountSecond,
        uint256 emissions,
        uint256 donation
    ) public {
        // Given: A valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A position with emissions above the gauge's flooring per 1e18 of stake.
        amount = uint128(bound(amount, 1, type(uint128).max - 1));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // And: Reward tokens reached the Asset Module outside an interaction, which the recipient claims.
        donation = bound(donation, 1, type(uint128).max);
        deal(receiptToken, address(stakedMetadex03AM), surplusState.lastRewardBalance + donation);
        uint256 claimable = surplusState.bookedSurplus + donation;
        assertEq(stakedMetadex03AM.claimableSurplus(), claimable);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(receiptToken).balanceOf(surplusRecipient), claimable);

        // And: The owner holds more LP, which with the staked amount fits the uint128 totalStaked.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));

        // When: The position increases its liquidity.
        _increasePosition(users.accountOwner, positionId, amountSecond);

        // Then: The position is credited the earned emissions of its staker alone.
        (,,, uint128 lastRewardPosition) = stakedMetadex03AM.positionState(positionId);
        assertEq(lastRewardPosition, earned);

        // And: The claimed emissions stay for the position, nothing extra is booked.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(
            ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)),
            surplusState.lastRewardBalance - surplusState.bookedSurplus + earned
        );

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_increaseLiquidity_DustMintOfOtherPosition(
        uint128 amount,
        uint128 amountSecond,
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

        // And: The penalty window of the position has passed.
        vm.roll(block.number + minStakeBlocks);
        uint256 gross = metadex03Gauge.earned(staker);
        assertGt(gross, net);

        // And: Another user mints a dust position in the same gauge.
        _mintPosition(users.unprivilegedAddress, 1);

        // When: The owner increases the liquidity of the position.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max / 3));
        _increasePosition(users.accountOwner, positionId, amountSecond);

        // Then: The full reward is credited, the dust mint opened no window on its staker.
        (,,, uint128 lastRewardPosition) = stakedMetadex03AM.positionState(positionId);
        assertEq(lastRewardPosition, gross);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), gross);
    }

    function testFuzz_Success_increaseLiquidity_IncreaseOfOtherPosition(
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
        amount = uint128(bound(amount, 1, type(uint128).max / 4));
        uint256 positionId = _mintPosition(users.accountOwner, amount);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: Emissions accrue, above what a penalty of a single pip rounds away.
        emissions = bound(emissions, MAX_PIPS + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 net = metadex03Gauge.earned(staker);

        // And: Another user mints a position in the gauge, both fitting the uint128 totalStaked.
        amountOther = uint128(bound(amountOther, 1, type(uint128).max / 4));
        uint256 positionIdOther = _mintPosition(users.liquidityProvider, amountOther);

        // And: The penalty windows of both positions have passed.
        vm.roll(block.number + minStakeBlocks);
        uint256 gross = metadex03Gauge.earned(staker);
        assertGt(gross, net);

        // And: The other position increases its liquidity.
        _increasePosition(users.liquidityProvider, positionIdOther, amountOther);

        // When: The owner increases the liquidity of the position.
        _increasePosition(users.accountOwner, positionId, amount);

        // Then: The full reward is credited, the other deposit opened no window on its staker.
        (,,, uint128 lastRewardPosition) = stakedMetadex03AM.positionState(positionId);
        assertEq(lastRewardPosition, gross);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), gross);
    }
}
