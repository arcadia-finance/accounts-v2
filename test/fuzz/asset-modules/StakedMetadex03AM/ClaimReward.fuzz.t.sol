/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ILeafVoter } from "../../../utils/fixtures/metadex03/interfaces/ILeafVoter.sol";
import { IMetadex03V2Gauge } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Gauge.sol";
import { IMetadex03V2GaugeFactory } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2GaugeFactory.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { IVoter } from "../../../utils/fixtures/metadex03/interfaces/IVoter.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "ClaimReward" function of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(reentrancy-no-eth)
contract ClaimReward_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_claimReward_PenaltyWindowOpen(
        uint128 lpBalance,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 blocksPassed
    ) public {
        // Given: A position staked in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        (, uint256 positionId) = _stakeInGaugeWithPenalty(lpBalance, minStakeBlocks, penaltyRate);

        // And: Emissions accrue, but the penalty window of the stake is still open.
        emissions = bound(emissions, 1, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        blocksPassed = bound(blocksPassed, 0, minStakeBlocks - 1);
        vm.roll(block.number + blocksPassed);

        // When: The Asset Module claims for the position.
        // Then: It reverts, nothing is haircut.
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)), 0);
    }

    function testFuzz_Revert_claimReward_GaugeTapeGasLimit(uint256 lpBalance, address gaugeTape) public {
        // Given: A position staked through its own staker.
        (, uint256 positionId) = _stakeInGauge(lpBalance);

        // And: A gauge tape whose gas limit exceeds the gas left in the call.
        vm.assume(gaugeTape != address(0));
        setGaugeTape(address(metadex03Gauge), gaugeTape, type(uint32).max);

        // When: The Asset Module claims for the position.
        // Then: It reverts.
        vm.expectRevert(IMetadex03V2GaugeFactory.InsufficientGasForCall.selector);
        stakedMetadex03AM.claimReward{ gas: 10_000_000 }(positionId, address(metadex03Pool));
    }

    function testFuzz_Revert_claimReward_ChainNotActiveOrSunset(uint256 lpBalance, uint256 emissions) public {
        // Given: A position staked through its own staker.
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);

        // And: Emissions accrue, above what the gauge's rewardPerToken floors away.
        emissions = bound(emissions, staked / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // And: The chain can no longer mint.
        setChainSuspended(true);

        // When: The Asset Module claims for the position.
        // Then: It reverts, only a withdrawal lets the gauge defer instead.
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
    }

    function testFuzz_Revert_claimReward_Root_CeilingExceeded(uint256 lpBalance, uint256 emissions) public {
        // Given: The protocol is staged on the root chain, with a staked position.
        _stageMetadex03(true);
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);

        // And: The earned amount reaches the redeem floor, within what the root Minter can mint.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + staked / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // And: The root Voter has no ceiling left for this chain.
        setChainCeiling(0);

        // When: The Asset Module claims for the position.
        // Then: The redeem is rejected by the root Voter, the revert is not swallowed.
        vm.expectRevert(IVoter.CeilingExceeded.selector);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
    }

    function testFuzz_Success_claimReward_Leaf(uint256 lpBalance, uint256 emissions) public {
        // Given: A position staked through its own staker.
        (, uint256 positionId) = _stakeInGauge(lpBalance);

        // And: Emissions accrue to the Gauge after the stake.
        emissions = bound(emissions, 1, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // When: The Asset Module claims for the position.
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The earned emissions of the staker are transferred to the Asset Module.
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)), earned);
    }

    function testFuzz_Success_claimReward_Root(uint256 lpBalance, uint256 emissions) public {
        // Given: The protocol is staged on the root chain, with a staked position.
        _stageMetadex03(true);
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);

        // And: The earned amount reaches the redeem floor, within what the root Minter can mint.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + staked / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // When: The Asset Module claims for the position.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The claim was redeemed for the Token, the ReceiptToken is burnt on the way through.
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), earned);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)), 0);
        assertEq(ERC20(receiptToken).balanceOf(emissionsHandler), 0);
    }

    function testFuzz_Success_claimReward_Leaf_PenaltyActive_OutsideWindow(
        uint128 lpBalance,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate
    ) public {
        // Given: A position staked in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        (uint256 staked, uint256 positionId) = _stakeInGaugeWithPenalty(lpBalance, minStakeBlocks, penaltyRate);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: Emissions accrue, above what a penalty of a single pip rounds away.
        emissions = bound(emissions, MAX_PIPS + staked / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 net = metadex03Gauge.earned(staker);

        // And: The penalty window of the stake ends exactly.
        vm.roll(block.number + minStakeBlocks);
        uint256 gross = metadex03Gauge.earned(staker);
        assertGt(gross, net);

        // When: The Asset Module claims for the position on the boundary of its window.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The full amount is delivered, waiting out the window lifts the haircut.
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)), gross);
    }

    function testFuzz_Success_claimReward_Leaf_OtherPenaltyWindowOpen(
        uint128 lpBalance,
        uint128 lpBalanceOther,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 blocksPassed
    ) public {
        // Given: A position staked in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        (uint256 staked, uint256 positionId) = _stakeInGaugeWithPenalty(lpBalance, minStakeBlocks, penaltyRate);

        // And: Emissions accrue, above what the gauge's per-1e18 flooring rounds away.
        emissions = bound(emissions, staked / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // And: The penalty window of the position has passed.
        vm.roll(vm.getBlockNumber() + minStakeBlocks);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        assertGt(earned, 0);

        // And: A second position is staked, its own penalty window is still open.
        _dealAndStake(address(metadex03Pool), lpBalanceOther);
        blocksPassed = bound(blocksPassed, 0, minStakeBlocks - 1);
        vm.roll(vm.getBlockNumber() + blocksPassed);

        // When: The Asset Module claims for the first position.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: Its staker's full reward is delivered, the other staker's window does not apply.
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)), earned);
    }

    function testFuzz_Success_claimReward_Root_PenaltyActive_OutsideWindow(
        uint128 lpBalance,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A position staked in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        (uint256 staked, uint256 positionId) = _stakeInGaugeWithPenalty(lpBalance, minStakeBlocks, penaltyRate);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: The earned amount reaches the redeem floor, above what a penalty of a single pip rounds away.
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + MAX_PIPS + staked / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 net = metadex03Gauge.earned(staker);

        // And: The penalty window of the stake has passed.
        vm.roll(block.number + minStakeBlocks);
        uint256 gross = metadex03Gauge.earned(staker);
        assertGt(gross, net);

        // When: The Asset Module claims for the position outside the penalty window.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The full amount is delivered in the Token, waiting out the window lifts the haircut.
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), gross);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)), 0);
    }

    function testFuzz_Success_claimReward_Root_ExactlyAtFloorIsDelivered(uint256 exponent) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A power-of-ten stake, which makes both of the gauge's flooring divisions exact.
        exponent = bound(exponent, 0, 24);
        (, uint256 positionId) = _stakeInGauge(10 ** exponent);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: The earned amount is exactly the redeem floor, which is not below it.
        addEmissionsToGauge(address(metadex03Gauge), MIN_REDEEM_AMOUNT);
        assertEq(metadex03Gauge.earned(staker), MIN_REDEEM_AMOUNT);
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), MIN_REDEEM_AMOUNT);

        // When: The Asset Module claims for the position.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The full amount is delivered in the Token, the floor is a strict lower bound.
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), MIN_REDEEM_AMOUNT);

        // And: Nothing is left behind, in the gauge nor for the next claim.
        assertEq(metadex03Gauge.deferredEmissions(staker), 0);
        assertEq(metadex03Gauge.earned(staker), 0);
        assertEq(stakedMetadex03AM.getCurrentReward(positionId, address(metadex03Pool)), 0);
    }

    function testFuzz_Success_claimReward_Root_BelowFloorThenBooked(
        uint256 lpBalance,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake small enough that a sub-floor reward can still clear the gauge's per-1e18 flooring.
        (uint256 staked, uint256 positionId) =
            _stakeInGauge(bound(lpBalance, 1, (MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI) * PRECISION));
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: The earned amount clears that flooring but stays below the redeem floor.
        emissionsFirst = bound(emissionsFirst, staked / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissionsFirst);
        uint256 held = metadex03Gauge.earned(staker);
        assertGt(held, 0);
        assertLt(held, MIN_REDEEM_AMOUNT);

        // When: The Asset Module claims for the position.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The handler holds the whole claim, nothing is delivered.
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), 0);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), held);

        // And: More emissions push the running total over the floor, within what the root Minter can mint.
        emissionsSecond = bound(
            emissionsSecond, MIN_REDEEM_AMOUNT + staked / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE - emissionsFirst
        );
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);
        uint256 earned = metadex03Gauge.earned(staker);

        // When: The Asset Module claims for the position again.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: What the handler held is booked, the position keeps the fresh accrual.
        assertEq(stakedMetadex03AM.bookedSurplus(), held);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), held);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), earned);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_claimReward_Root_HeldReleasedByClaimOnAnotherAsset(
        uint256 lpBalance,
        uint128 amountStable,
        uint256 emissionsVolatile,
        uint256 emissionsStable,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The protocol is staged on the root chain, with a small volatile position.
        _stageMetadex03(true);
        (uint256 staked, uint256 positionIdVolatile) = _stakeInGauge(bound(lpBalance, 1, PRECISION));

        // And: A claim left the volatile sub-floor accrual with the handler, held in full.
        emissionsVolatile = bound(emissionsVolatile, MIN_REDEEM_AMOUNT / 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissionsVolatile);
        stakedMetadex03AM.claimReward(positionIdVolatile, address(metadex03Pool));
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));
        assertGt(held, 0);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), 0);

        // And: The stable pool of the same pair has its own gauge, with a position of its own.
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), true);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(stablePool));
        address stableGauge = address(createGaugeMetadex03(address(stablePool)));
        stakedMetadex03AM.addAsset(stableGauge);
        (uint256 stakedStable, uint256 positionIdStable) = _dealAndStake(address(stablePool), amountStable);

        // And: The stable gauge accrues over the redeem floor, within what the root Minter can mint.
        emissionsStable = bound(
            emissionsStable,
            MIN_REDEEM_AMOUNT + stakedStable / PRECISION + GAUGE_ROUNDING_WEI,
            MAX_BASE_RATE - emissionsVolatile - staked
        );
        addEmissionsToGauge(stableGauge, emissionsStable);
        uint256 earned = IMetadex03V2Gauge(stableGauge).earned(stakedMetadex03AM.getStaker(positionIdStable));

        // When: The Asset Module claims for the stable position.
        stakedMetadex03AM.claimReward(positionIdStable, address(stablePool));

        // Then: The hold is booked for the recipient, the stable position keeps only its own leg.
        assertEq(stakedMetadex03AM.bookedSurplus(), held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), held);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), earned);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_claimReward_Leaf_DonationNotCredited(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint256 emissions,
        uint256 donation
    ) public {
        // Given: A valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A position with emissions above the gauge's flooring per 1e18 of stake.
        vm.assume(amount != 0);
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

        // When: The position claims.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionId);

        // Then: The owner is paid the earned emissions of its staker alone.
        assertEq(ERC20(receiptToken).balanceOf(users.accountOwner), earned);

        // And: Nothing stays behind, nothing extra is booked.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(
            ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)),
            surplusState.lastRewardBalance - surplusState.bookedSurplus
        );

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_claimReward_Root_DonationNotCredited(
        StakingAMStateForSurplus memory surplusState,
        uint128 amount,
        uint256 emissions,
        uint256 donation
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A valid surplus state.
        givenValidStakingAMState(surplusState);
        setStakedMetadex03AMState(surplusState);

        // And: A position earning at or above the redeem floor.
        vm.assume(amount != 0);
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // And: Reward tokens reached the Asset Module outside an interaction, which the recipient claims.
        donation = bound(donation, 1, type(uint128).max);
        deal(rootToken, address(stakedMetadex03AM), surplusState.lastRewardBalance + donation);
        uint256 claimable = surplusState.bookedSurplus + donation;
        assertEq(stakedMetadex03AM.claimableSurplus(), claimable);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), claimable);

        // When: The position claims.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionId);

        // Then: The owner is paid the earned emissions of its staker alone.
        assertEq(ERC20(rootToken).balanceOf(users.accountOwner), earned);

        // And: Nothing stays behind, nothing extra is booked.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(
            ERC20(rootToken).balanceOf(address(stakedMetadex03AM)),
            surplusState.lastRewardBalance - surplusState.bookedSurplus
        );

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }
}
