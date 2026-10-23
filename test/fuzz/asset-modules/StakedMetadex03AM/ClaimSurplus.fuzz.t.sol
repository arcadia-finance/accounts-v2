/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { StakedMetadex03AM_Fuzz_Test, StakingAM } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "claimSurplus" of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(reentrancy-no-eth)
contract ClaimSurplus_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_claimSurplus_NothingToClaim(uint256 lpBalance, address recipient) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // And: A staked pool, and nothing reached this contract outside an interaction.
        _stakeInGauge(lpBalance);

        // When: Calling claimSurplus().
        vm.recordLogs();
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();

        // Then: Nothing is emitted and nothing is transferred.
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(ERC20(receiptToken).balanceOf(surplusRecipient), 0);
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_claimSurplus_Leaf_Donation(uint256 lpBalance, uint256 donation, address recipient)
        public
    {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A staked pool on a leaf chain.
        _stakeInGauge(lpBalance);

        // And: Reward tokens reached this contract outside a claim.
        donation = bound(donation, 1, type(uint128).max);
        deal(receiptToken, address(stakedMetadex03AM), donation);

        // When: Calling claimSurplus().
        // Then: The donation is paid to the recipient.
        vm.expectEmit(address(stakedMetadex03AM));
        emit StakingAM.SurplusClaimed(surplusRecipient, donation);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();

        // And: Nothing is left for the stakers.
        assertEq(ERC20(receiptToken).balanceOf(surplusRecipient), donation);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_claimSurplus_Root_Donation(uint256 lpBalance, uint256 donation, address recipient)
        public
    {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A staked pool on the root chain.
        _stageMetadex03(true);
        _stakeInGauge(lpBalance);

        // And: Reward tokens reached this contract outside a claim.
        donation = bound(donation, 1, type(uint128).max);
        deal(rootToken, address(stakedMetadex03AM), donation);

        // When: Calling claimSurplus().
        // Then: The donation is paid to the recipient.
        vm.expectEmit(address(stakedMetadex03AM));
        emit StakingAM.SurplusClaimed(surplusRecipient, donation);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();

        // And: Nothing is left for the stakers.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), donation);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_claimSurplus_Root_ReleasedByLp(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        GaugeState memory gaugeState,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A claim left the gauge's deferred emissions with the handler, below its redeem floor.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId, uint256 deferredEmissions) = _initHeldDeferredRewards(amount, emissions, withdrawAmount);

        // And: An unrelated LP released the handler by naming this contract as their claim recipient.
        givenValidGaugeState(gaugeState, metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionId)));
        depositInGauge(address(metadex03Gauge), users.liquidityProvider, gaugeState.stake);
        addEmissionsToGauge(address(metadex03Gauge), gaugeState.emissions);
        claimEmissionsTo(address(metadex03Gauge), users.liquidityProvider, address(stakedMetadex03AM));
        uint256 released = ERC20(rootToken).balanceOf(address(stakedMetadex03AM));
        assertGe(released, deferredEmissions);

        // When: Calling claimSurplus().
        // Then: What the handler released is paid to the recipient.
        vm.expectEmit(address(stakedMetadex03AM));
        emit StakingAM.SurplusClaimed(surplusRecipient, released);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();

        // And: Nothing is left for the stakers, and the owner was paid nothing.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), released);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), 0);
        assertEq(ERC20(rootToken).balanceOf(users.accountOwner), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_claimSurplus_Root_SubFloorReleasedByLp(
        uint256 lpBalance,
        uint256 emissions,
        GaugeState memory gaugeState,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake for which the gauge's flooring rounds away at most one wei.
        (, uint256 positionId) = _stakeInGauge(bound(lpBalance, 1, PRECISION));
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: An accrual below the redeem floor, with no deferred emissions anywhere.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT / 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        assertEq(metadex03Gauge.deferredEmissions(staker), 0);

        // And: A claim for the position left it with the handler, which holds it in full.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));
        assertGt(held, 0);

        // And: An unrelated LP released the handler by naming this contract as their claim recipient.
        givenValidGaugeState(gaugeState, metadex03Gauge.balanceOf(staker));
        depositInGauge(address(metadex03Gauge), users.liquidityProvider, gaugeState.stake);
        addEmissionsToGauge(address(metadex03Gauge), gaugeState.emissions);
        claimEmissionsTo(address(metadex03Gauge), users.liquidityProvider, address(stakedMetadex03AM));
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);
        uint256 released = ERC20(rootToken).balanceOf(address(stakedMetadex03AM));
        assertGe(released, held);

        // When: Calling claimSurplus().
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();

        // Then: What the handler held is paid to the recipient, never credited to a position.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), released);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function testFuzz_Success_claimSurplus_Root_ReleasedByLpOfAnotherGauge(
        uint256 lpBalance,
        uint256 emissions,
        GaugeState memory gaugeState,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake for which the gauge's flooring rounds away at most one wei.
        (, uint256 positionId) = _stakeInGauge(bound(lpBalance, 1, PRECISION));

        // And: A claim left the volatile sub-floor accrual with the handler, held in full.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT / 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));
        assertGt(held, 0);

        // And: The stable pool of the same pair has a gauge this contract never staked in.
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), true);
        address stableGauge = address(createGaugeMetadex03(address(stablePool)));

        // And: An LP of that other gauge claimed their own emissions, naming this contract as the recipient.
        givenValidGaugeState(gaugeState, 1);
        depositInGauge(stableGauge, users.liquidityProvider, gaugeState.stake);
        addEmissionsToGauge(stableGauge, gaugeState.emissions);
        claimEmissionsTo(stableGauge, users.liquidityProvider, address(stakedMetadex03AM));
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);
        uint256 released = ERC20(rootToken).balanceOf(address(stakedMetadex03AM));
        assertGe(released, held);

        // When: Calling claimSurplus().
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();

        // Then: What the handler held for the volatile gauge is paid to the recipient as well.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), released);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_claimSurplus_Leaf_DonationThenInteraction(
        uint128 amount,
        uint256 emissions,
        uint256 donation,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A position with emissions above the gauge's flooring per 1e18 of stake.
        vm.assume(amount != 0);
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        uint256 positionId = _initPositionWithEarned(amount, emissions);
        uint256 ownReward = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // And: Reward tokens reached the Asset Module outside an interaction.
        donation = bound(donation, 1, type(uint128).max);
        deal(receiptToken, address(stakedMetadex03AM), donation);

        // And: The position claims its reward afterwards.
        vm.prank(users.accountOwner);
        assertEq(stakedMetadex03AM.claimReward(positionId), ownReward);

        // When: Calling claimSurplus().
        assertEq(stakedMetadex03AM.claimableSurplus(), donation);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();

        // Then: The recipient received the donation the interaction did not absorb.
        assertEq(ERC20(receiptToken).balanceOf(surplusRecipient), donation);
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(stakedMetadex03AM.claimableSurplus(), 0);

        // And: The reward of the position was paid in full.
        assertEq(ERC20(receiptToken).balanceOf(users.accountOwner), ownReward);
    }

    function testFuzz_Success_claimSurplus_Root_DonationThenHeldReleased(
        uint128 amount,
        uint256 emissions,
        uint256 emissionsSecond,
        uint256 withdrawAmount,
        uint256 donation,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A claim left the gauge's deferred emissions with the handler, below its redeem floor.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId, uint256 deferredEmissions) = _initHeldDeferredRewards(amount, emissions, withdrawAmount);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), deferredEmissions);

        // And: Reward tokens reached the Asset Module outside an interaction.
        donation = bound(donation, 1, type(uint128).max);
        deal(rootToken, address(stakedMetadex03AM), donation);

        // And: Fresh emissions bring the live reward of the staker over the redeem floor.
        emissionsSecond = bound(emissionsSecond, MIN_REDEEM_AMOUNT, MAX_BASE_RATE - MIN_REDEEM_AMOUNT);
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);
        uint256 ownReward = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        vm.assume(ownReward >= MIN_REDEEM_AMOUNT);

        // And: The position claims, which releases the handler's hold with its live reward.
        vm.prank(users.accountOwner);
        assertEq(stakedMetadex03AM.claimReward(positionId), ownReward);

        // When: Calling claimSurplus().
        assertEq(stakedMetadex03AM.claimableSurplus(), donation + deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();

        // Then: The recipient received the donation and the released hold.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), donation + deferredEmissions);
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(stakedMetadex03AM.claimableSurplus(), 0);

        // And: The reward of the position was paid in full.
        assertEq(ERC20(rootToken).balanceOf(users.accountOwner), ownReward);
    }
}
