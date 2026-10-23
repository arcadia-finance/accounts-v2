/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { IEmissionsHandler } from "../../../../src/asset-modules/Metadex03/interfaces/IEmissionsHandler.sol";
import { IMetadex03V2Gauge } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Gauge.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "GetCurrentReward" function of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(reentrancy-no-eth)
contract GetCurrentReward_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getCurrentReward_Leaf_ChainSuspended(uint256 lpBalance, uint256 emissions) public {
        // Given: A staked position that earned emissions.
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);
        emissions = bound(emissions, staked / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        assertGt(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), 0);

        // When: The chain can no longer mint.
        setChainSuspended(true);

        // Then: Nothing is credited, a claim could not deliver it.
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), 0);
    }

    function testFuzz_Success_getCurrentReward_Root_BelowMinRedeemAmount(uint256 lpBalance, uint256 emissions) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A staked position whose earned emissions stay below the redeem floor.
        (, uint256 positionId) = _stakeInGauge(lpBalance);
        emissions = bound(emissions, 1, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        assertLt(metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId)), MIN_REDEEM_AMOUNT);

        // When: Calling getCurrentReward().
        // Then: Nothing is credited, the root handler defers a sub-floor total instead of delivering it.
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), 0);
    }

    function testFuzz_Success_getCurrentReward_Leaf(uint256 lpBalance, uint256 emissions) public {
        // Given: A staked position.
        (, uint256 positionId) = _stakeInGauge(lpBalance);

        // And: No reward is credited before any emissions accrued.
        uint256 currentReward = stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool));
        assertEq(currentReward, 0);

        // And: Emissions accrue to the metadex03Gauge, within its uint128 reward share.
        emissions = bound(emissions, 1, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // When: Calling getCurrentReward().
        currentReward = stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool));

        // Then: The credited reward equals what the staker of the position earned in the gauge.
        assertEq(currentReward, earned);
    }

    function testFuzz_Success_getCurrentReward_Leaf_OtherPositionNotCredited(
        uint256 lpBalance,
        uint256 lpBalanceOther,
        uint256 emissions
    ) public {
        // Given: Two staked positions in the same gauge.
        (, uint256 positionId) = _stakeInGauge(lpBalance);
        (, uint256 positionIdOther) = _dealAndStake(address(metadex03Pool), lpBalanceOther);

        // And: Emissions accrue to the metadex03Gauge, within its uint128 reward share.
        emissions = bound(emissions, 1, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        uint256 earnedOther = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther));

        // When: Calling getCurrentReward() for both positions.
        // Then: Each position is credited what its own staker earned.
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), earned);
        assertEq(stakedMetadex03AM.getCurrentReward(positionIdOther, address(metadex03Pool)), earnedOther);
    }

    function testFuzz_Success_getCurrentReward_Root_AboveMinRedeemAmount(uint256 lpBalance, uint256 emissions) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A staked position whose earned emissions reach the redeem floor.
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + staked / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        assertGe(earned, MIN_REDEEM_AMOUNT);

        // When: Calling getCurrentReward().
        // Then: The full earned amount is credited.
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), earned);
    }

    function testFuzz_Success_getCurrentReward_Leaf_PenaltyAndReferralActive(
        uint128 lpBalance,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        address referral,
        uint256 referralShare
    ) public {
        // Given: A gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);

        // And: The same GaugeFactory pays a share of the emissions to a referral other than the Asset Module.
        referralShare = bound(referralShare, 1, MAX_PIPS);
        vm.assume(referral != address(0));
        vm.assume(referral != address(stakedMetadex03AM));
        setReferralConfig(address(metadex03Gauge), referral, referralShare);

        // And: A position is staked through its own staker, inside the penalty window.
        (uint256 staked, uint256 positionId) = _dealAndStake(address(metadex03Pool), lpBalance);

        // And: Emissions accrue, above what a penalty of a single pip rounds away.
        emissions = bound(emissions, MAX_PIPS + staked / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // When: Calling getCurrentReward().
        uint256 currentReward = stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool));

        // Then: The valuation equals the net earned amount, never the gross emissions.
        assertEq(currentReward, earned);
        assertLt(currentReward, emissions);

        // And: A claim inside the window is blocked, the haircut is never realised.
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
    }

    function testFuzz_Success_getCurrentReward_Root_PenaltyAndReferralActive(
        uint128 lpBalance,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        address referral,
        uint256 referralShare
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A gauge whose GaugeFactory penalises an early unstake, short of taking the whole reward.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS - 1);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);

        // And: The same GaugeFactory pays a share short of the whole reward to a referral other than the Asset Module.
        referralShare = bound(referralShare, 1, MAX_PIPS - 1);
        vm.assume(referral != address(0));
        vm.assume(referral != address(stakedMetadex03AM));
        setReferralConfig(address(metadex03Gauge), referral, referralShare);

        // And: A position is staked through its own staker, inside the penalty window.
        (uint256 staked, uint256 positionId) = _dealAndStake(address(metadex03Pool), lpBalance);

        // And: Emissions large enough that both haircuts together still leave the net at the redeem floor.
        emissions = bound(
            emissions, MIN_REDEEM_AMOUNT * MAX_PIPS * MAX_PIPS + staked / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE
        );
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        assertGe(earned, MIN_REDEEM_AMOUNT);

        // When: Calling getCurrentReward().
        uint256 currentReward = stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool));

        // Then: The redeem floor is measured against the net earned amount, which is credited in full.
        assertEq(currentReward, earned);
        assertLt(currentReward, emissions);

        // And: A claim inside the window is blocked, the haircut is never realised.
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
    }

    function testFuzz_Success_getCurrentReward_Leaf_ExcludesDeferredRewards(uint128 amount, uint256 emissions) public {
        // Given: A position with non-zero earned emissions.
        vm.assume(amount != 0);
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        address staker = stakedMetadex03AM.getStaker(positionId);
        uint256 earned = metadex03Gauge.earned(staker);
        assertGt(earned, 0);

        // And: The chain is active, but the mint reverts.
        vm.mockCallRevert(address(leafVoter), abi.encodeWithSignature("mintEmissions(address[],uint128[])"), "");

        // When: The position is withdrawn, which defers what it could not mint.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, amount);
        vm.clearMockedCalls();

        // Then: The deferred emissions are owed to the recipient, not to the position.
        assertEq(metadex03Gauge.deferredEmissions(staker), earned);
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), 0);
    }

    function testFuzz_Success_getCurrentReward_Root_ExcludesDeferredRewards(uint128 amount, uint256 emissions) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A position whose earned emissions reach the redeem floor.
        vm.assume(amount != 0);
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        address staker = stakedMetadex03AM.getStaker(positionId);
        uint256 earned = metadex03Gauge.earned(staker);
        assertGe(earned, MIN_REDEEM_AMOUNT);

        // And: The chain is active, but the mint reverts.
        vm.mockCallRevert(address(leafVoter), abi.encodeWithSignature("mintEmissions(address[],uint128[])"), "");

        // When: The position is withdrawn, which defers what it could not mint.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, amount);
        vm.clearMockedCalls();

        // Then: The deferred emissions still clear the redeem floor, so the zero comes from netting it out.
        assertEq(metadex03Gauge.deferredEmissions(staker), earned);
        assertGe(metadex03Gauge.earned(staker), MIN_REDEEM_AMOUNT);
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), 0);
    }

    function testFuzz_Success_getCurrentReward_Leaf_NetsDeferredRewardsFromFreshEmissions(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        uint256 emissionsFresh
    ) public {
        // Given: A position that keeps a stake after a partial withdrawal.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max));

        // And: The chain was suspended over the withdrawal, so the gauge holds stale deferred emissions.
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max / 2);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertEq(metadex03Gauge.deferredEmissions(staker), deferredEmissions);

        // And: A second emission leg that also clears the flooring and still fits the uint128 reward share.
        emissionsFresh =
            bound(emissionsFresh, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max - emissions);

        // When: The fresh, mintable emissions accrue on top of the stale deferred emissions.
        addEmissionsToGauge(address(metadex03Gauge), emissionsFresh);

        // Then: Only the fresh accrual is credited, the deferred emissions go to the recipient.
        uint256 fresh = metadex03Gauge.earned(staker) - deferredEmissions;
        assertGt(fresh, 0);
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), fresh);
    }

    function testFuzz_Success_getCurrentReward_Root_NetsDeferredRewardsFromFreshEmissions(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        uint256 emissionsFresh
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake small enough that a sub-floor second leg still clears the gauge's per-1e18 flooring.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, (MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI) * PRECISION));

        // And: The chain was suspended over a partial withdrawal, leaving deferred emissions at the redeem floor.
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE / 2);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);
        assertEq(metadex03Gauge.deferredEmissions(staker), deferredEmissions);

        // And: A second emission leg that clears the flooring but stays below the redeem floor on its own.
        emissionsFresh = bound(emissionsFresh, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);

        // When: The fresh, mintable emissions accrue on top of the stale deferred emissions.
        addEmissionsToGauge(address(metadex03Gauge), emissionsFresh);

        // Then: The sub-floor fresh accrual is credited, the floor is read on the gross earned amount.
        uint256 fresh = metadex03Gauge.earned(staker) - deferredEmissions;
        assertGt(fresh, 0);
        assertLt(fresh, MIN_REDEEM_AMOUNT);
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), fresh);
    }

    function testFuzz_Success_getCurrentReward_Leaf_SuspendedDeferredRewardsGoToRecipient(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: A position that keeps a stake after a partial withdrawal.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max));

        // When: A withdrawal while suspended deferred the earned emissions.
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        assertGt(deferredEmissions, 0);

        // Then: The deferred emissions are not offered to the position.
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), deferredEmissions);
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), 0);

        // And: A valid deferred rewards recipient is set.
        _givenSurplusRecipient(recipient);

        // And: The next claim of the position books the deferred emissions for that recipient.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(receiptToken).balanceOf(recipient), deferredEmissions);
    }

    function testFuzz_Success_getCurrentReward_Root_SuspendedDeferredRewardsGoToRecipient(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A position that keeps a stake after a partial withdrawal.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max));

        // When: A withdrawal while suspended deferred emissions at the redeem floor.
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);

        // Then: The deferred emissions are not offered to the position.
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), deferredEmissions);
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), 0);

        // And: A valid deferred rewards recipient is set.
        _givenSurplusRecipient(recipient);

        // And: The next claim of the position redeems the deferred emissions and books the Token.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(recipient), deferredEmissions);
    }

    function testFuzz_Success_getCurrentReward_Root_PendingRedeemsNotCredited(
        uint256 lpBalance,
        uint256 emissionsFirst,
        uint256 emissionsSecond
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake for which the gauge's flooring rounds away at most one wei.
        (uint256 staked, uint256 positionId) = _stakeInGauge(bound(lpBalance, 1, PRECISION));

        // And: A first accrual, below the redeem floor, that the handler defers in full.
        emissionsFirst = bound(emissionsFirst, MIN_REDEEM_AMOUNT / 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissionsFirst);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        assertGt(IEmissionsHandler(emissionsHandler).pendingRedeems(address(stakedMetadex03AM)), 0);

        // And: A second accrual that clears the redeem floor on its own.
        emissionsSecond = bound(
            emissionsSecond, MIN_REDEEM_AMOUNT + staked / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE - emissionsFirst
        );
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // When: Calling getCurrentReward().
        // Then: Only the fresh accrual is credited, what the handler defers is settled on the claim itself.
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), earned);
    }

    function testFuzz_Success_getCurrentReward_Root_OtherGaugePendingRedeemsNotCredited(
        uint256 lpBalance,
        uint256 lpBalanceOther,
        uint256 emissionsFirst,
        uint256 emissionsOther
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: The volatile position parked a sub-floor accrual of its own with the handler.
        (, uint256 positionId) = _stakeInGauge(bound(lpBalance, 1, PRECISION));
        emissionsFirst = bound(emissionsFirst, MIN_REDEEM_AMOUNT / 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissionsFirst);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        uint256 pendingAmount = IEmissionsHandler(emissionsHandler).pendingRedeems(address(stakedMetadex03AM));
        assertGt(pendingAmount, 0);

        // And: The stable pool of the same pair has its own gauge and its own position.
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), true);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(stablePool));
        address stableGauge = address(createGaugeMetadex03(address(stablePool)));
        stakedMetadex03AM.addAsset(stableGauge);
        (uint256 stakedOther, uint256 positionIdOther) =
            _dealAndStake(address(stablePool), bound(lpBalanceOther, 1, PRECISION));

        // And: The stable gauge accrues emissions that clear the redeem floor on their own.
        emissionsOther = bound(
            emissionsOther,
            MIN_REDEEM_AMOUNT + stakedOther / PRECISION + GAUGE_ROUNDING_WEI,
            MAX_BASE_RATE - emissionsFirst
        );
        addEmissionsToGauge(stableGauge, emissionsOther);
        uint256 earnedOther = IMetadex03V2Gauge(stableGauge).earned(stakedMetadex03AM.getStaker(positionIdOther));

        // When: Calling getCurrentReward() for the stable position.
        // Then: Only its own accrual is credited.
        assertEq(stakedMetadex03AM.getCurrentReward(positionIdOther, address(stablePool)), earnedOther);
    }

    function testFuzz_Success_getCurrentReward_Root_PendingCompletesFloor(
        uint128 amount,
        uint256 emissionsHeld,
        uint256 emissionsFresh
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A claim left a sub floor amount with the emissions handler.
        amount = uint128(bound(amount, 1, PRECISION));
        emissionsHeld = bound(emissionsHeld, 4, MIN_REDEEM_AMOUNT - 1);
        uint256 positionId = _initPositionWithEarned(amount, emissionsHeld);
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionId);
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));
        vm.assume(held > 2);

        // And: The staker earns less than the floor, but enough to release the held amount.
        emissionsFresh = bound(emissionsFresh, MIN_REDEEM_AMOUNT - held + 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissionsFresh);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        vm.assume(earned < MIN_REDEEM_AMOUNT && earned + held >= MIN_REDEEM_AMOUNT);

        // When: Calling getCurrentReward().
        // Then: The earned amount is credited, a claim releases it together with the held amount.
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), earned);

        // And: A claim of the position delivers the earned amount.
        vm.prank(users.accountOwner);
        assertEq(stakedMetadex03AM.claimReward(positionId), earned);
    }

    function testFuzz_Success_getCurrentReward_Root_PendingReachesFloorExactly(uint256 emissionsHeld) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A claim of a position staking one unit left a sub floor amount with the handler.
        emissionsHeld = bound(emissionsHeld, 1, MIN_REDEEM_AMOUNT - 1);
        uint256 positionId = _initPositionWithEarned(PRECISION, emissionsHeld);
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionId);
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));

        // And: The staker earns exactly what the held amount lacks of the floor.
        addEmissionsToGauge(address(metadex03Gauge), MIN_REDEEM_AMOUNT - held);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        assertEq(earned + held, MIN_REDEEM_AMOUNT);

        // When: Calling getCurrentReward().
        // Then: The earned amount is credited, a total at the floor is redeemed.
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), earned);
    }
}
