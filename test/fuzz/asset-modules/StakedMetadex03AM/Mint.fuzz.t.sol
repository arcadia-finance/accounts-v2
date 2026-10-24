/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import {
    StakedMetadex03AM_Fuzz_Test,
    AbstractStakingAM_Fuzz_Test,
    StakingAM,
    ERC20Mock
} from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "mint" of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract Mint_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    function testFuzz_Revert_mint_ZeroAmount(address asset) public {
        // Given: Any asset.

        // When: Calling mint() for a zero amount.
        // Then: It reverts.
        vm.expectRevert(StakingAM.ZeroAmount.selector);
        stakedMetadex03AM.mint(asset, 0);
    }

    function testFuzz_Revert_mint_AssetNotAllowed(uint8 assetDecimals, uint128 amount, address account_) public {
        // Given: An ERC20 with a realistic amount of decimals, not added to the Asset Module.
        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        address asset = address(new ERC20Mock("Asset", "AST", assetDecimals));

        // And: The Account holds a non-zero balance of it, approved to the Asset Module.
        amount = uint128(bound(amount, 1, type(uint128).max));
        deal(asset, account_, amount, true);
        vm.prank(account_);
        ERC20Mock(asset).approve(address(stakedMetadex03AM), amount);

        // When: Calling mint() for that asset.
        // Then: It reverts.
        vm.prank(account_);
        vm.expectRevert(StakingAM.AssetNotAllowed.selector);
        stakedMetadex03AM.mint(asset, amount);
    }

    function testFuzz_Success_mint_OtherPenaltyWindowOpen(
        uint128 amount,
        uint128 amountSecond,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 blocksPassed
    ) public {
        // Given: A position minted in a gauge whose GaugeFactory penalises an early unstake.
        amount = uint128(bound(amount, 1, type(uint128).max - 1));
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);
        address stakerFirst = stakedMetadex03AM.getStaker(_mintPosition(users.accountOwner, amount));
        uint256 depositBlockFirst = metadex03Gauge.depositBlock(stakerFirst);

        // And: The penalty window of the first deposit is still open.
        blocksPassed = bound(blocksPassed, 0, minStakeBlocks - 1);
        vm.roll(block.number + blocksPassed);

        // When: A second staker mints a position, both fitting the uint128 totalStaked.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));
        uint256 positionId = _mintPosition(users.liquidityProvider, amountSecond);

        // Then: The position is minted.
        assertEq(stakedMetadex03AM.ownerOf(positionId), users.liquidityProvider);
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionId)), amountSecond);

        // And: The penalty window of the first position is left untouched.
        assertEq(metadex03Gauge.depositBlock(stakerFirst), depositBlockFirst);
    }

    function testFuzz_Success_mint_ChainSuspended_OtherPositionEarned(
        uint128 amount,
        uint128 amountSecond,
        uint256 emissions
    ) public {
        // Given: A position with emissions above the gauge's flooring per 1e18 of stake, so its earned is non-zero.
        amount = uint128(bound(amount, 1, type(uint128).max - 1));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        address stakerFirst = stakedMetadex03AM.getStaker(_initPositionWithEarned(amount, emissions));
        uint256 earned = metadex03Gauge.earned(stakerFirst);
        assertGt(earned, 0);

        // And: The chain is suspended.
        setChainSuspended(true);

        // When: A second staker mints a position, both fitting the uint128 totalStaked.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));
        uint256 positionId = _mintPosition(users.liquidityProvider, amountSecond);

        // Then: The position is minted, the mint claimed nothing for the first position.
        assertEq(stakedMetadex03AM.ownerOf(positionId), users.liquidityProvider);
        assertEq(metadex03Gauge.earned(stakerFirst), earned);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), 0);
    }

    function testFuzz_Success_mint_TotalStakedForAssetGreaterThan0(
        AbstractStakingAM_Fuzz_Test.StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        address account_
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        {
            // And: Valid state of a first position.
            givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);

            // And: State is persisted.
            setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), 1);

            // And: Amount staked is non-zero and the updated totalStaked still fits a uint128.
            vm.assume(assetState.totalStaked < type(uint128).max);
            amount = uint128(bound(amount, 1, type(uint128).max - assetState.totalStaked));

            // And: Account has a balance of metadex03Pool LP tokens, approved to the Asset Module.
            deal(address(metadex03Pool), account_, amount);
            vm.prank(account_);
            ERC20Mock(address(metadex03Pool)).approve(address(stakedMetadex03AM), amount);
        }

        // When: A user is staking via the Staking Module.
        // Then: The liquidity is increased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(2, address(metadex03Pool), amount);
        uint256 positionId = stakedMetadex03AM.mint(address(metadex03Pool), amount);
        vm.stopPrank();

        // And: Assets should have been staked through the staker of the new position.
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionId)), amount);

        // And: The staker of the first position is untouched, its emissions are not claimed.
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(1)), positionState.amountStaked);
        assertEq(metadex03Gauge.earned(stakedMetadex03AM.getStaker(1)), assetState.currentRewardGlobal);

        // And: New position has been minted to Account.
        assertEq(stakedMetadex03AM.ownerOf(positionId), account_);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(metadex03Pool));
        assertEq(newPositionState.amountStaked, amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked + amount);
        assertEq(
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)),
            surplusState.lastRewardBalance + positionState.lastRewardPosition
        );
    }

    function testFuzz_Success_mint_TotalStakedForAssetIsZero(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        address account_
    ) public canReceiveERC721(account_) {
        // Given: The Account can hold a position.
        vm.assume(account_ != address(0));

        // And: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid surplus state, without any staked position.
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: Amount staked is greater than zero.
        vm.assume(amount != 0);

        // And: Account has a balanceOf metadex03Pool LP tokens.
        deal(address(metadex03Pool), account_, amount);
        vm.prank(account_);
        ERC20Mock(address(metadex03Pool)).approve(address(stakedMetadex03AM), amount);

        // When: A user is staking via the Staking Module.
        // Then: The liquidity is increased.
        vm.startPrank(account_);
        vm.expectEmit();
        emit StakingAM.LiquidityIncreased(1, address(metadex03Pool), amount);
        uint256 positionId = stakedMetadex03AM.mint(address(metadex03Pool), amount);
        vm.stopPrank();

        // And: The staker of the position is deployed and holds the full stake.
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertGt(staker.code.length, 0);
        assertEq(metadex03Gauge.balanceOf(staker), amount);
        assertEq(metadex03Gauge.totalSupply(), amount);

        // And: New position has been minted to Account.
        assertEq(stakedMetadex03AM.ownerOf(positionId), account_);

        // And: Position state should be updated correctly.
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(metadex03Pool));
        assertEq(newPositionState.amountStaked, amount);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: Asset state should be updated correctly.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, 0);
        assertEq(newAssetState.totalStaked, amount);
    }

    function testFuzz_Success_mint_ChainSuspended_ZeroEarned(uint128 amount, uint128 amountSecond) public {
        // Given: A position without earned emissions.
        amount = uint128(bound(amount, 1, type(uint128).max - 1));
        _initPositionWithEarned(amount, 0);

        // And: The chain is suspended.
        setChainSuspended(true);

        // When: A second staker mints a position, both fitting the uint128 totalStaked.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));
        uint256 positionId = _mintPosition(users.liquidityProvider, amountSecond);

        // Then: The position is minted.
        assertEq(stakedMetadex03AM.ownerOf(positionId), users.liquidityProvider);
    }

    function testFuzz_Success_mint_DonationNotCredited(
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
        address stakerFirst = stakedMetadex03AM.getStaker(_initPositionWithEarned(amount, emissions));
        uint256 earned = metadex03Gauge.earned(stakerFirst);

        // And: Reward tokens reached the Asset Module outside an interaction, which the recipient claims.
        donation = bound(donation, 1, type(uint128).max);
        deal(receiptToken, address(stakedMetadex03AM), surplusState.lastRewardBalance + donation);
        uint256 claimable = surplusState.bookedSurplus + donation;
        assertEq(stakedMetadex03AM.claimableSurplus(), claimable);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20Mock(receiptToken).balanceOf(surplusRecipient), claimable);

        // When: A second staker mints a position, both fitting the uint128 totalStaked.
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));
        uint256 positionId = _mintPosition(users.liquidityProvider, amountSecond);

        // Then: The fresh position is credited nothing.
        (,,, uint128 lastRewardPosition) = stakedMetadex03AM.positionState(positionId);
        assertEq(lastRewardPosition, 0);

        // And: The emissions of the earlier staker stay in the gauge, nothing extra is booked.
        assertEq(metadex03Gauge.earned(stakerFirst), earned);
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(
            ERC20Mock(receiptToken).balanceOf(address(stakedMetadex03AM)),
            surplusState.lastRewardBalance - surplusState.bookedSurplus
        );

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }
}
