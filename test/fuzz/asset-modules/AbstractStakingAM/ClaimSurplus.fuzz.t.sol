/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test, ERC20Mock, StakingAM } from "./_AbstractStakingAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "claimSurplus" of contract "StakingAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ClaimSurplus_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_claimSurplus_NotRecipient(
        StakingAMStateForSurplus memory surplusState,
        address caller,
        uint128 donation
    ) public {
        // Given: A recipient is set and reward tokens reached the Asset Module.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(address(rewardToken), address(stakingAM), surplusState.lastRewardBalance + donation, true);

        // And: The caller is not the recipient.
        vm.assume(caller != surplusState.surplusRecipient);

        // When: The caller claims the surplus.
        // Then: It reverts.
        vm.prank(caller);
        vm.expectRevert(StakingAM.NotRecipient.selector);
        stakingAM.claimSurplus();
    }

    function testFuzz_Success_claimSurplus_NothingToClaim(StakingAMStateForSurplus memory surplusState) public {
        // Given: A recipient is set and nothing is booked.
        givenValidStakingAMState(surplusState);
        surplusState.bookedSurplus = 0;
        setStakingAMState(surplusState);
        assertEq(stakingAM.claimableSurplus(), 0);

        // When: Calling claimSurplus().
        vm.recordLogs();
        vm.prank(surplusState.surplusRecipient);
        stakingAM.claimSurplus();

        // Then: Nothing is emitted and nothing is transferred.
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(rewardToken.balanceOf(surplusState.surplusRecipient), 0);
        assertEq(rewardToken.balanceOf(address(stakingAM)), surplusState.lastRewardBalance);

        // And: The booked surplus and the cached balance are untouched.
        assertEq(stakingAM.bookedSurplus(), 0);
        assertEq(stakingAM.getLastRewardBalance(), surplusState.lastRewardBalance);
    }

    function testFuzz_Success_claimSurplus_Donation(StakingAMStateForSurplus memory surplusState, uint128 donation)
        public
    {
        // Given: A recipient is set.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);

        // And: Reward tokens reached the Asset Module outside an interaction.
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(address(rewardToken), address(stakingAM), surplusState.lastRewardBalance + donation, true);
        uint256 claimable = surplusState.bookedSurplus + donation;
        assertEq(stakingAM.claimableSurplus(), claimable);

        // When: Calling claimSurplus().
        // Then: The SurplusClaimed event is emitted.
        vm.expectEmit(address(stakingAM));
        emit StakingAM.SurplusClaimed(surplusState.surplusRecipient, claimable);
        vm.prank(surplusState.surplusRecipient);
        stakingAM.claimSurplus();

        // And: The recipient received it and nothing is left claimable.
        assertEq(rewardToken.balanceOf(surplusState.surplusRecipient), claimable);
        assertEq(stakingAM.bookedSurplus(), 0);
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
        assertEq(stakingAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_Booked(
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals,
        uint128 amount,
        uint128 reward,
        uint128 booked
    ) public {
        // Given: A recipient is set and an Asset is added.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);
        address asset = addAsset(assetDecimals);

        // And: A position is staked, whose stake keeps the reward accumulator in range.
        amount = uint128(bound(amount, 1e18, type(uint128).max / 2));
        uint256 positionId = _stakeSolePosition(asset, amount);

        // And: A claim booked a part of the delivered reward for the recipient.
        reward = uint128(bound(reward, 1, type(uint128).max));
        booked = uint128(bound(booked, 1, reward));
        stakingAM.setActualRewardBalance(asset, reward);
        stakingAM.setBookedAmount(booked);
        vm.prank(users.liquidityProvider);
        stakingAM.claimReward(positionId);
        uint256 claimable = surplusState.bookedSurplus + booked;
        assertEq(stakingAM.claimableSurplus(), claimable);

        // When: Calling claimSurplus().
        vm.expectEmit(address(stakingAM));
        emit StakingAM.SurplusClaimed(surplusState.surplusRecipient, claimable);
        vm.prank(surplusState.surplusRecipient);
        stakingAM.claimSurplus();

        // Then: The recipient received the booked amount.
        assertEq(rewardToken.balanceOf(surplusState.surplusRecipient), claimable);
        assertEq(stakingAM.bookedSurplus(), 0);
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
        assertEq(stakingAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_BookedAndDonation(
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals,
        uint128 amount,
        uint128 reward,
        uint128 booked,
        uint128 donation
    ) public {
        // Given: A recipient is set and an Asset is added.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);
        address asset = addAsset(assetDecimals);

        // And: A position is staked, whose stake keeps the reward accumulator in range.
        amount = uint128(bound(amount, 1e18, type(uint128).max / 2));
        uint256 positionId = _stakeSolePosition(asset, amount);

        // And: A claim booked a part of the delivered reward for the recipient.
        reward = uint128(bound(reward, 1, type(uint128).max));
        booked = uint128(bound(booked, 1, reward));
        stakingAM.setActualRewardBalance(asset, reward);
        stakingAM.setBookedAmount(booked);
        vm.prank(users.liquidityProvider);
        stakingAM.claimReward(positionId);

        // And: Reward tokens reached the Asset Module after that claim.
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(address(rewardToken), address(stakingAM), rewardToken.balanceOf(address(stakingAM)) + donation, true);
        uint256 claimable = surplusState.bookedSurplus + booked + donation;
        assertEq(stakingAM.claimableSurplus(), claimable);

        // When: Calling claimSurplus().
        vm.prank(surplusState.surplusRecipient);
        stakingAM.claimSurplus();

        // Then: The recipient received both legs.
        assertEq(rewardToken.balanceOf(surplusState.surplusRecipient), claimable);
        assertEq(stakingAM.bookedSurplus(), 0);
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
        assertEq(stakingAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_PositionRewardUntouched(
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals,
        uint128 amount,
        uint128 reward,
        uint128 booked
    ) public {
        // Given: A recipient is set and an Asset is added.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);
        address asset = addAsset(assetDecimals);

        // And: A position is staked, whose stake keeps the reward accumulator in range.
        amount = uint128(bound(amount, 1e18, type(uint128).max / 2));
        uint256 positionId = _stakeSolePosition(asset, amount);

        // And: A reward accrued of which a part is booked, credited to the position by a second interaction.
        reward = uint128(bound(reward, 1, type(uint128).max));
        booked = uint128(bound(booked, 1, reward));
        stakingAM.setActualRewardBalance(asset, reward);
        stakingAM.setBookedAmount(booked);
        deal(asset, users.liquidityProvider, 1, true);
        vm.startPrank(users.liquidityProvider);
        ERC20Mock(asset).approve(address(stakingAM), 1);
        stakingAM.increaseLiquidity(positionId, 1);
        vm.stopPrank();
        uint256 expectedReward = stakingAM.rewardOf(positionId);
        assertEq(expectedReward, _credited(amount, reward - booked));

        // When: Calling claimSurplus().
        vm.prank(surplusState.surplusRecipient);
        stakingAM.claimSurplus();

        // Then: The reward of the position is unchanged and paid in full.
        assertEq(stakingAM.rewardOf(positionId), expectedReward);
        vm.prank(users.liquidityProvider);
        assertEq(stakingAM.claimReward(positionId), expectedReward);
        assertEq(rewardToken.balanceOf(users.liquidityProvider), expectedReward);
    }

    function testFuzz_Success_claimSurplus_DonationThenInteraction(
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals,
        uint128 amount,
        uint128 reward,
        uint128 donation
    ) public {
        // Given: A recipient is set and an Asset is added.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);
        address asset = addAsset(assetDecimals);

        // And: A position is staked, whose stake keeps the reward accumulator in range.
        amount = uint128(bound(amount, 1e18, type(uint128).max / 2));
        uint256 positionId = _stakeSolePosition(asset, amount);

        // And: Reward tokens reached the Asset Module outside an interaction.
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(address(rewardToken), address(stakingAM), surplusState.lastRewardBalance + donation, true);

        // And: The position claims a reward afterwards.
        reward = uint128(bound(reward, 1, type(uint128).max));
        stakingAM.setActualRewardBalance(asset, reward);
        uint256 expectedReward = _credited(amount, reward);
        vm.prank(users.liquidityProvider);
        assertEq(stakingAM.claimReward(positionId), expectedReward);

        // When: Calling claimSurplus().
        uint256 claimable = surplusState.bookedSurplus + donation;
        assertEq(stakingAM.claimableSurplus(), claimable);
        vm.expectEmit(address(stakingAM));
        emit StakingAM.SurplusClaimed(surplusState.surplusRecipient, claimable);
        vm.prank(surplusState.surplusRecipient);
        stakingAM.claimSurplus();

        // Then: The recipient received the donation the interaction did not absorb.
        assertEq(rewardToken.balanceOf(surplusState.surplusRecipient), claimable);
        assertEq(stakingAM.bookedSurplus(), 0);
        assertEq(stakingAM.claimableSurplus(), 0);

        // And: The reward of the position was paid in full and is unaffected.
        assertEq(rewardToken.balanceOf(users.liquidityProvider), expectedReward);
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }

    function testFuzz_Success_claimSurplus_TwoDonationsAcrossTwoInteractions(
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals,
        uint128 amount,
        uint128 donationFirst,
        uint128 donationSecond
    ) public {
        // Given: A recipient is set and an Asset is added.
        givenValidStakingAMState(surplusState);
        setStakingAMState(surplusState);
        address asset = addAsset(assetDecimals);

        // And: A position is staked, whose stake keeps the reward accumulator in range.
        amount = uint128(bound(amount, 1e18, type(uint128).max / 2));
        uint256 positionId = _stakeSolePosition(asset, amount);

        // And: A donation is followed by an interaction that delivers nothing.
        donationFirst = uint128(bound(donationFirst, 1, type(uint128).max / 2));
        deal(address(rewardToken), address(stakingAM), surplusState.lastRewardBalance + donationFirst, true);
        vm.prank(users.liquidityProvider);
        stakingAM.claimReward(positionId);

        // And: A second donation is followed by a second such interaction.
        donationSecond = uint128(bound(donationSecond, 1, type(uint128).max / 2));
        deal(
            address(rewardToken),
            address(stakingAM),
            surplusState.lastRewardBalance + uint256(donationFirst) + donationSecond,
            true
        );
        vm.prank(users.liquidityProvider);
        stakingAM.claimReward(positionId);

        // When: Calling claimSurplus().
        uint256 claimable = surplusState.bookedSurplus + uint256(donationFirst) + donationSecond;
        assertEq(stakingAM.claimableSurplus(), claimable);
        vm.prank(surplusState.surplusRecipient);
        stakingAM.claimSurplus();

        // Then: The recipient received both donations.
        assertEq(rewardToken.balanceOf(surplusState.surplusRecipient), claimable);
        assertEq(stakingAM.bookedSurplus(), 0);
        assertEq(stakingAM.claimableSurplus(), 0);
        assertEq(stakingAM.getLastRewardBalance(), rewardToken.balanceOf(address(stakingAM)));
    }
}
