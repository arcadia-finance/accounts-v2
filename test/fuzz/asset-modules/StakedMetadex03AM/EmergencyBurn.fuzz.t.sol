/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { IMetadex03V2Gauge } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Gauge.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test, StakingAM, ERC20Mock } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "emergencyBurn" of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract EmergencyBurn_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_emergencyBurn_NotOwner(uint256 positionId, address owner, address caller) public {
        // Given: The caller is not the owner of the position.
        vm.assume(caller != owner);
        stakedMetadex03AM.setOwnerOfPositionId(owner, positionId);

        // When: The caller burns the position.
        // Then: It reverts.
        vm.prank(caller);
        vm.expectRevert(StakingAM.NotOwner.selector);
        stakedMetadex03AM.emergencyBurn(positionId);
    }

    function testFuzz_Revert_emergencyBurn_EmergencyWithdrawDisabled(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The metadex03Pool and its gauge are onboarded.
        _addGauge();

        // And: Valid state is persisted for a non-zero position.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: The gauge factory disables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(false);

        // When: The Account burns the position.
        // Then: It reverts.
        vm.prank(account_);
        vm.expectRevert(IMetadex03V2Gauge.EmergencyWithdrawDisabled.selector);
        stakedMetadex03AM.emergencyBurn(positionId);
    }

    function testFuzz_Success_emergencyBurn_NonZeroReward(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint256 donation
    ) public canReceiveERC721(account_) {
        // Given: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state is persisted for a non-zero position.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: The credited reward of the position is non-zero.
        vm.assume(positionState.lastRewardPosition > 0);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: Reward tokens reached the Asset Module outside an interaction.
        donation = bound(donation, 0, type(uint128).max);
        deal(
            receiptToken,
            address(stakedMetadex03AM),
            surplusState.lastRewardBalance + positionState.lastRewardPosition + donation
        );

        // And: The gauge factory enables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);

        // When: The Account burns the position.
        // Then: The credited reward is paid out and the liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit(true, true, true, true, address(stakedMetadex03AM));
        emit StakingAM.RewardPaid(positionId, receiptToken, positionState.lastRewardPosition);
        vm.expectEmit(true, true, true, true, address(stakedMetadex03AM));
        emit StakingAM.LiquidityDecreased(positionId, address(metadex03Pool), positionState.amountStaked);
        uint256 rewards = stakedMetadex03AM.emergencyBurn(positionId);
        vm.stopPrank();

        // And: The Account gets the staked amount and the credited reward.
        assertEq(rewards, positionState.lastRewardPosition);
        assertEq(metadex03Pool.balanceOf(account_), positionState.amountStaked);
        assertEq(ERC20Mock(receiptToken).balanceOf(account_), positionState.lastRewardPosition);

        // And: The staker of the position and the Asset Module hold no stake.
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionId)), 0);
        assertEq(metadex03Pool.balanceOf(address(stakedMetadex03AM)), 0);

        // And: The positionId is burned and its state deleted.
        assertEq(stakedMetadex03AM.balanceOf(account_), 0);
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: The total staked of the asset drops by the staked amount.
        StakingAM.AssetState memory newAssetState;
        (newAssetState.lastRewardPerTokenGlobal, newAssetState.totalStaked,) =
            stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);

        // And: The donation is booked as surplus and the reward token balance is cached.
        assertEq(stakedMetadex03AM.bookedSurplus(), surplusState.bookedSurplus + donation);
        assertEq(
            ERC20Mock(receiptToken).balanceOf(address(stakedMetadex03AM)), surplusState.lastRewardBalance + donation
        );
        assertEq(stakedMetadex03AM.getLastRewardBalance(), surplusState.lastRewardBalance + donation);
    }

    function testFuzz_Success_emergencyBurn_ZeroReward(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint256 donation
    ) public canReceiveERC721(account_) {
        // Given: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state with a zero credited reward is persisted for a non-zero position.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        positionState.lastRewardPosition = 0;
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: Reward tokens reached the Asset Module outside an interaction.
        donation = bound(donation, 0, type(uint128).max);
        deal(receiptToken, address(stakedMetadex03AM), surplusState.lastRewardBalance + donation);

        // And: The gauge factory enables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);

        // When: The Account burns the position.
        // Then: The liquidity is decreased.
        vm.startPrank(account_);
        vm.expectEmit(true, true, true, true, address(stakedMetadex03AM));
        emit StakingAM.LiquidityDecreased(positionId, address(metadex03Pool), positionState.amountStaked);
        uint256 rewards = stakedMetadex03AM.emergencyBurn(positionId);
        vm.stopPrank();

        // And: The Account gets the staked amount and no reward tokens.
        assertEq(rewards, 0);
        assertEq(metadex03Pool.balanceOf(account_), positionState.amountStaked);
        assertEq(ERC20Mock(receiptToken).balanceOf(account_), 0);

        // And: The staker of the position holds no stake.
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionId)), 0);

        // And: The positionId is burned and its state deleted.
        assertEq(stakedMetadex03AM.balanceOf(account_), 0);
        StakingAM.PositionState memory newPositionState;
        (
            newPositionState.asset,
            newPositionState.amountStaked,
            newPositionState.lastRewardPerTokenPosition,
            newPositionState.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionId);
        assertEq(newPositionState.asset, address(0));
        assertEq(newPositionState.amountStaked, 0);
        assertEq(newPositionState.lastRewardPerTokenPosition, 0);
        assertEq(newPositionState.lastRewardPosition, 0);

        // And: The total staked of the asset drops by the staked amount.
        StakingAM.AssetState memory newAssetState;
        (, newAssetState.totalStaked,) = stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(newAssetState.totalStaked, assetState.totalStaked - positionState.amountStaked);

        // And: The donation is booked as surplus and the reward token balance is cached.
        assertEq(stakedMetadex03AM.bookedSurplus(), surplusState.bookedSurplus + donation);
        assertEq(stakedMetadex03AM.getLastRewardBalance(), surplusState.lastRewardBalance + donation);
    }

    function testFuzz_Success_emergencyBurn_OtherPositionUntouched(
        uint128 amount,
        uint128 amountOther,
        uint256 emissions
    ) public {
        // Given: Positions of the account owner and the liquidity provider in one gauge.
        amount = uint128(bound(amount, 1, type(uint128).max / 2));
        emissions = bound(emissions, 0, type(uint128).max / 2);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        amountOther = uint128(bound(amountOther, 1, type(uint128).max / 2));
        uint256 positionIdOther = _mintPosition(users.liquidityProvider, amountOther);
        address stakerOther = stakedMetadex03AM.getStaker(positionIdOther);
        uint256 earnedOther = metadex03Gauge.earned(stakerOther);

        // And: The gauge factory enables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);

        // When: The account owner burns its position.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.emergencyBurn(positionId);

        // Then: The staker of the other position keeps its stake and its earned emissions.
        assertEq(metadex03Gauge.balanceOf(stakerOther), amountOther);
        assertEq(metadex03Gauge.earned(stakerOther), earnedOther);

        // And: The other position and its owner are untouched.
        assertEq(stakedMetadex03AM.balanceOf(users.liquidityProvider), 1);
        StakingAM.PositionState memory positionStateOther;
        (
            positionStateOther.asset,
            positionStateOther.amountStaked,
            positionStateOther.lastRewardPerTokenPosition,
            positionStateOther.lastRewardPosition
        ) = stakedMetadex03AM.positionState(positionIdOther);
        assertEq(positionStateOther.asset, address(metadex03Pool));
        assertEq(positionStateOther.amountStaked, amountOther);
        assertEq(positionStateOther.lastRewardPerTokenPosition, 0);
        assertEq(positionStateOther.lastRewardPosition, 0);

        // And: Only the other position remains staked for the asset.
        (, uint128 totalStaked,) = stakedMetadex03AM.assetState(address(metadex03Pool));
        assertEq(totalStaked, amountOther);
    }

    function testFuzz_Success_emergencyBurn_LeafVoterReverts(uint128 amount, uint256 emissions) public {
        // Given: A position with emissions above the gauge's flooring per 1e18 of stake.
        amount = uint128(bound(amount, 1, type(uint128).max));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        assertGt(metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId)), 0);

        // And: The gauge factory enables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);

        // And: Every call to the LeafVoter reverts.
        vm.mockCallRevert(address(leafVoter), bytes(""), bytes(""));

        // When: The account owner burns the position.
        vm.prank(users.accountOwner);
        uint256 rewards = stakedMetadex03AM.emergencyBurn(positionId);

        // Then: The position leaves with its Asset and no reward.
        assertEq(rewards, 0);
        assertEq(metadex03Pool.balanceOf(users.accountOwner), amount);
        assertEq(ERC20Mock(receiptToken).balanceOf(users.accountOwner), 0);
        assertEq(stakedMetadex03AM.balanceOf(users.accountOwner), 0);
    }

    function testFuzz_Success_emergencyBurn_NonZeroReward_LeafVoterReverts(
        uint96 positionId,
        address account_,
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState
    ) public canReceiveERC721(account_) {
        // Given: The metadex03Pool and its gauge are onboarded.
        _addGauge();
        vm.assume(account_ != address(metadex03Pool));
        vm.assume(account_ != metadex03Pool.poolFees());
        vm.assume(account_ != address(metadex03Gauge));
        vm.assume(account_ != address(leafVoter));

        // And: Valid state with a non-zero credited reward is persisted for a non-zero position.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);
        vm.assume(positionState.lastRewardPosition > 0);

        // And: Position is minted to the Account.
        stakedMetadex03AM.mintIdTo(account_, positionId);

        // And: The Asset Module holds the credited reward.
        deal(
            receiptToken, address(stakedMetadex03AM), surplusState.lastRewardBalance + positionState.lastRewardPosition
        );

        // And: The gauge factory enables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);

        // And: Every call to the LeafVoter reverts.
        vm.mockCallRevert(address(leafVoter), bytes(""), bytes(""));

        // When: The Account burns the position.
        vm.prank(account_);
        uint256 rewards = stakedMetadex03AM.emergencyBurn(positionId);

        // Then: The Account gets the staked amount and the credited reward.
        assertEq(rewards, positionState.lastRewardPosition);
        assertEq(metadex03Pool.balanceOf(account_), positionState.amountStaked);
        assertEq(ERC20Mock(receiptToken).balanceOf(account_), positionState.lastRewardPosition);
        assertEq(stakedMetadex03AM.balanceOf(account_), 0);

        // And: The reward token balance is cached.
        assertEq(stakedMetadex03AM.getLastRewardBalance(), surplusState.lastRewardBalance);
    }

    function testFuzz_Success_emergencyBurn_PenaltyWindowOpen(uint128 amount, uint256 emissions) public {
        // Given: A gauge with an open penalty window.
        amount = uint128(bound(amount, 1e6, type(uint64).max));
        emissions = bound(emissions, 1e18, 1e24);
        _addGaugeWithPenalty(1000, 500_000);

        // And: A position with earned emissions.
        uint256 positionId = _mintPosition(users.accountOwner, amount);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // And: A normal claim reverts.
        vm.prank(users.accountOwner);
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.claimReward(positionId);

        // And: The gauge factory enables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);

        // And: Every call to the LeafVoter reverts.
        vm.mockCallRevert(address(leafVoter), bytes(""), bytes(""));

        // When: The account owner burns the position.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.emergencyBurn(positionId);

        // Then: The position leaves with its Asset.
        assertEq(metadex03Pool.balanceOf(users.accountOwner), amount);
        assertEq(stakedMetadex03AM.balanceOf(users.accountOwner), 0);
    }

    function testFuzz_Success_emergencyBurn_DonatedStake(uint128 amount, uint128 donation) public {
        // Given: A position in the gauge.
        amount = uint128(bound(amount, 1, type(uint64).max));
        donation = uint128(bound(donation, 1, type(uint64).max));
        _addGauge();
        uint256 positionId = _mintPosition(users.accountOwner, amount);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: A third party deposits a stake on behalf of the staker of the position.
        deal(address(metadex03Pool), users.liquidityProvider, donation);
        vm.startPrank(users.liquidityProvider);
        metadex03Pool.approve(address(metadex03Gauge), donation);
        metadex03Gauge.depositFor(donation, staker);
        vm.stopPrank();

        // And: The gauge factory enables emergency withdrawals.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);

        // When: The account owner burns the position.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.emergencyBurn(positionId);

        // Then: Only the staked amount of the position leaves the gauge.
        assertEq(metadex03Pool.balanceOf(users.accountOwner), amount);
        assertEq(metadex03Gauge.balanceOf(staker), donation);
        assertEq(stakedMetadex03AM.balanceOf(users.accountOwner), 0);
    }
}
