/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test, StakingAM } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "claimDeferredRewards" of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ClaimDeferredRewards_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_claimDeferredRewards_GaugeNotValid(address gauge_, uint256 positionId, address sender)
        public
    {
        // Given: A pool with its gauge onboarded on the Asset Module.
        _addGauge();

        // And: The gauge that is claimed from is not the onboarded gauge of its pool.
        vm.assume(gauge_ != address(metadex03Gauge));
        vm.assume(gauge_ != address(0));

        // When: The sender claims the deferred emissions.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(StakedMetadex03AM.GaugeNotValid.selector);
        stakedMetadex03AM.claimDeferredRewards(gauge_, positionId);
    }

    function testFuzz_Revert_claimDeferredRewards_PositionNotBurned(uint128 amount, address sender) public {
        // Given: A live position.
        amount = uint128(bound(amount, 1, type(uint128).max));
        uint256 positionId = _initPositionWithEarned(amount, 0);

        // When: The sender claims the deferred emissions of the position.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(StakedMetadex03AM.PositionNotBurned.selector);
        stakedMetadex03AM.claimDeferredRewards(address(metadex03Gauge), positionId);
    }

    function testFuzz_Success_claimDeferredRewards_NoDeferred_Burned(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint256 emissions,
        address sender
    ) public {
        // Given: A valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A position is burned while the chain mints, so nothing is deferred.
        amount = uint128(bound(amount, 1, type(uint128).max));
        emissions = bound(emissions, 0, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, amount);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), 0);
        uint256 recipientBalance = ERC20(receiptToken).balanceOf(surplusRecipient);

        // When: The sender claims the deferred emissions of the position.
        vm.prank(sender);
        stakedMetadex03AM.claimDeferredRewards(address(metadex03Gauge), positionId);

        // Then: Nothing is transferred.
        assertEq(ERC20(receiptToken).balanceOf(surplusRecipient), recipientBalance);

        // And: The surplus state of the Asset Module is untouched.
        assertEq(stakedMetadex03AM.bookedSurplus(), surplusState.bookedSurplus);
        assertEq(stakedMetadex03AM.getLastRewardBalance(), surplusState.lastRewardBalance);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), surplusState.lastRewardBalance);
    }

    function testFuzz_Success_claimDeferredRewards_NoDeferred_NeverMinted(
        StakingAMStateForSurplus memory surplusState,
        uint256 positionId,
        address sender
    ) public {
        // Given: A valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A pool with its gauge onboarded, and a position that was never minted.
        _addGauge();
        uint256 recipientBalance = ERC20(receiptToken).balanceOf(surplusRecipient);

        // When: The sender claims the deferred emissions of the position.
        vm.prank(sender);
        stakedMetadex03AM.claimDeferredRewards(address(metadex03Gauge), positionId);

        // Then: Nothing is transferred.
        assertEq(ERC20(receiptToken).balanceOf(surplusRecipient), recipientBalance);

        // And: The surplus state of the Asset Module is untouched.
        assertEq(stakedMetadex03AM.bookedSurplus(), surplusState.bookedSurplus);
        assertEq(stakedMetadex03AM.getLastRewardBalance(), surplusState.lastRewardBalance);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), surplusState.lastRewardBalance);
    }

    function testFuzz_Success_claimDeferredRewards_Leaf(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint128 amountOther,
        uint256 emissions,
        uint256 emissionsOther,
        address sender
    ) public {
        // Given: A valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A position burned while suspended, deferring emissions above the gauge's flooring.
        amount = uint128(bound(amount, 1, type(uint128).max / 2));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max / 2);

        // And: A live position in the same gauge, which accrued emissions of its own.
        amountOther = uint128(bound(amountOther, 1, type(uint128).max / 2));
        emissionsOther = bound(emissionsOther, 0, type(uint128).max / 2);
        (uint256 positionId, uint256 positionIdOther) =
            _initBurnedDeferredAndLivePosition(amount, emissions, amountOther, emissionsOther);
        uint256 deferredEmissions = metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId));
        assertGt(deferredEmissions, 0);
        uint256 earnedOther = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther));
        uint256 recipientBalance = ERC20(receiptToken).balanceOf(surplusRecipient);

        // When: The sender claims the deferred emissions of the burned position.
        vm.prank(sender);
        stakedMetadex03AM.claimDeferredRewards(address(metadex03Gauge), positionId);

        // Then: The recipient received exactly the deferred emissions of the staker.
        assertEq(ERC20(receiptToken).balanceOf(surplusRecipient), recipientBalance + deferredEmissions);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), 0);

        // And: The surplus state of the Asset Module is untouched.
        assertEq(stakedMetadex03AM.bookedSurplus(), surplusState.bookedSurplus);
        assertEq(stakedMetadex03AM.getLastRewardBalance(), surplusState.lastRewardBalance);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), surplusState.lastRewardBalance);

        // And: The staker of the live position is untouched.
        assertEq(metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther)), earnedOther);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionIdOther)), 0);

        // And: The state of the live position is untouched.
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
    }

    function testFuzz_Success_claimDeferredRewards_AfterEmergencyBurn(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address sender
    ) public {
        // Given: A position whose staker holds deferred emissions.
        amount = uint128(bound(amount, 1e6, type(uint64).max));
        emissions = bound(emissions, 1e18, 1e24);
        (uint256 positionId,) = _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        address staker = stakedMetadex03AM.getStaker(positionId);
        uint256 deferredEmissions = metadex03Gauge.deferredEmissions(staker);
        assertGt(deferredEmissions, 0);

        // And: The position is burned through the emergency withdrawal while the LeafVoter reverts.
        metadex03GaugeFactory.setEmergencyWithdrawEnabled(true);
        vm.mockCallRevert(address(leafVoter), bytes(""), bytes(""));
        vm.prank(users.accountOwner);
        stakedMetadex03AM.emergencyBurn(positionId);
        assertEq(metadex03Gauge.deferredEmissions(staker), deferredEmissions);

        // And: The LeafVoter recovers.
        vm.clearMockedCalls();
        uint256 recipientBalance = ERC20(receiptToken).balanceOf(surplusRecipient);

        // When: The sender claims the deferred emissions of the burned position.
        vm.prank(sender);
        stakedMetadex03AM.claimDeferredRewards(address(metadex03Gauge), positionId);

        // Then: The recipient received exactly the deferred emissions of the staker.
        assertEq(ERC20(receiptToken).balanceOf(surplusRecipient), recipientBalance + deferredEmissions);
        assertEq(metadex03Gauge.deferredEmissions(staker), 0);
    }

    function testFuzz_Success_claimDeferredRewards_Root_AboveMinRedeemAmount(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint128 amountOther,
        uint256 emissions,
        uint256 emissionsOther,
        address sender
    ) public {
        // Given: The protocol is staged on the root chain, with a valid surplus state.
        _stageMetadex03(true);
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A position burned while suspended, deferring emissions above the redeem floor.
        amount = uint128(bound(amount, 1, type(uint128).max / 2));
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE / 2);

        // And: A live position in the same gauge, which accrued emissions of its own.
        amountOther = uint128(bound(amountOther, 1, type(uint128).max / 2));
        emissionsOther = bound(emissionsOther, 0, MAX_BASE_RATE / 2);
        (uint256 positionId, uint256 positionIdOther) =
            _initBurnedDeferredAndLivePosition(amount, emissions, amountOther, emissionsOther);
        uint256 deferredEmissions = metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId));
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);
        uint256 earnedOther = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther));
        uint256 pendingRecipient = pendingRedeemsOf(surplusRecipient);
        uint256 recipientBalance = ERC20(rootToken).balanceOf(surplusRecipient);

        // When: The sender claims the deferred emissions of the burned position.
        vm.prank(sender);
        stakedMetadex03AM.claimDeferredRewards(address(metadex03Gauge), positionId);

        // Then: The handler redeemed its hold and the deferred emissions for the recipient.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), recipientBalance + pendingRecipient + deferredEmissions);
        assertEq(pendingRedeemsOf(surplusRecipient), 0);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), 0);

        // And: The surplus state of the Asset Module is untouched.
        assertEq(stakedMetadex03AM.bookedSurplus(), surplusState.bookedSurplus);
        assertEq(stakedMetadex03AM.getLastRewardBalance(), surplusState.lastRewardBalance);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), surplusState.lastRewardBalance);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);

        // And: The staker of the live position is untouched.
        assertEq(metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther)), earnedOther);
    }

    function testFuzz_Success_claimDeferredRewards_Root_BelowMinRedeemAmount(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint128 amountOther,
        uint256 emissions,
        uint256 emissionsOther,
        address sender
    ) public {
        // Given: The protocol is staged on the root chain, with a valid surplus state.
        _stageMetadex03(true);
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A position burned while suspended, deferring emissions below the redeem floor.
        amount = uint128(bound(amount, 1, (MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI) * PRECISION));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);

        // And: A live position in the same gauge, which accrued emissions of its own.
        amountOther = uint128(bound(amountOther, 1, type(uint128).max / 2));
        emissionsOther = bound(emissionsOther, 0, MAX_BASE_RATE / 2);
        (uint256 positionId, uint256 positionIdOther) =
            _initBurnedDeferredAndLivePosition(amount, emissions, amountOther, emissionsOther);
        uint256 deferredEmissions = metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId));
        assertGt(deferredEmissions, 0);
        uint256 earnedOther = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther));
        uint256 pendingRecipient = pendingRedeemsOf(surplusRecipient);
        assertLt(pendingRecipient + deferredEmissions, MIN_REDEEM_AMOUNT);
        uint256 recipientBalance = ERC20(rootToken).balanceOf(surplusRecipient);

        // When: The sender claims the deferred emissions of the burned position.
        vm.prank(sender);
        stakedMetadex03AM.claimDeferredRewards(address(metadex03Gauge), positionId);

        // Then: The handler holds the deferred emissions for the recipient, nothing is redeemed.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), recipientBalance);
        assertEq(pendingRedeemsOf(surplusRecipient), pendingRecipient + deferredEmissions);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), 0);

        // And: The surplus state of the Asset Module is untouched.
        assertEq(stakedMetadex03AM.bookedSurplus(), surplusState.bookedSurplus);
        assertEq(stakedMetadex03AM.getLastRewardBalance(), surplusState.lastRewardBalance);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), surplusState.lastRewardBalance);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);

        // And: The staker of the live position is untouched.
        assertEq(metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther)), earnedOther);
    }
}
