/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "claimSurplus" of contract "StakedSlipstreamAM".
 */
contract ClaimSurplus_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_claimSurplus_NotRecipient(address recipient, address caller, uint128 donation) public {
        // Given: A recipient is set and reward tokens reached the Asset Module.
        _givenSurplusRecipient(recipient);
        // forge-lint: disable-next-item(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(AERO, address(stakedSlipstreamAM), donation, true);

        // And: The caller is not the recipient.
        vm.assume(caller != recipient);

        // When: The caller claims the surplus.
        // Then: It reverts.
        vm.prank(caller);
        vm.expectRevert(StakedSlipstreamAM.NotRecipient.selector);
        stakedSlipstreamAM.claimSurplus();
    }

    function testFuzz_Success_claimSurplus_NothingToClaim(address recipient) public {
        // Given: A recipient is set and nothing is claimable.
        _givenSurplusRecipient(recipient);
        assertEq(stakedSlipstreamAM.claimableSurplus(), 0);

        // When: Calling claimSurplus().
        vm.recordLogs();
        vm.prank(recipient);
        stakedSlipstreamAM.claimSurplus();

        // Then: Nothing is emitted and nothing is transferred.
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(ERC20(AERO).balanceOf(recipient), 0);
        assertEq(ERC20(AERO).balanceOf(address(stakedSlipstreamAM)), 0);

        // And: Nothing is left claimable.
        assertEq(stakedSlipstreamAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_Donation(address recipient, uint128 donation) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // And: Reward tokens reached the Asset Module outside an interaction.
        // forge-lint: disable-next-item(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(AERO, address(stakedSlipstreamAM), donation, true);
        assertEq(stakedSlipstreamAM.claimableSurplus(), donation);

        // When: Calling claimSurplus().
        // Then: The SurplusClaimed event is emitted.
        vm.expectEmit(address(stakedSlipstreamAM));
        emit StakedSlipstreamAM.SurplusClaimed(recipient, donation);
        vm.prank(recipient);
        stakedSlipstreamAM.claimSurplus();

        // And: The recipient received it and nothing is left claimable.
        assertEq(ERC20(AERO).balanceOf(recipient), donation);
        assertEq(stakedSlipstreamAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_Booked(
        address recipient,
        StakedSlipstreamAM.PositionState memory position,
        uint256 reward,
        uint256 booked,
        int24 tick
    ) public {
        // Given: A claim booked a part of the delivery for the recipient.
        (uint256 assetId, uint256 earned) = _initStakedPositionWithEarned(position, tick, reward, recipient);
        booked = bound(booked, 1, earned);
        stakedSlipstreamAM.setBookedAmount(booked);
        vm.prank(users.liquidityProvider);
        stakedSlipstreamAM.claimReward(assetId);
        assertEq(stakedSlipstreamAM.claimableSurplus(), booked);

        // When: Calling claimSurplus().
        vm.expectEmit(address(stakedSlipstreamAM));
        emit StakedSlipstreamAM.SurplusClaimed(recipient, booked);
        vm.prank(recipient);
        stakedSlipstreamAM.claimSurplus();

        // Then: The recipient received the booked amount.
        assertEq(ERC20(AERO).balanceOf(recipient), booked);
        assertEq(stakedSlipstreamAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_BookedAndDonation(
        address recipient,
        StakedSlipstreamAM.PositionState memory position,
        uint256 reward,
        uint256 booked,
        uint128 donation,
        int24 tick
    ) public {
        // Given: A claim booked a part of the delivery for the recipient.
        (uint256 assetId, uint256 earned) = _initStakedPositionWithEarned(position, tick, reward, recipient);
        booked = bound(booked, 1, earned);
        stakedSlipstreamAM.setBookedAmount(booked);
        vm.prank(users.liquidityProvider);
        stakedSlipstreamAM.claimReward(assetId);

        // And: Reward tokens reached the Asset Module after that claim.
        // forge-lint: disable-next-item(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(AERO, address(stakedSlipstreamAM), booked + donation, false);

        // When: Calling claimSurplus().
        vm.prank(recipient);
        stakedSlipstreamAM.claimSurplus();

        // Then: The recipient received both legs.
        assertEq(ERC20(AERO).balanceOf(recipient), booked + donation);
        assertEq(stakedSlipstreamAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_PositionRewardUntouched(
        address recipient,
        StakedSlipstreamAM.PositionState memory position,
        uint256 reward,
        uint128 donation,
        int24 tick
    ) public {
        // Given: A staked position with a reward earned.
        (uint256 assetId, uint256 earned) = _initStakedPositionWithEarned(position, tick, reward, recipient);

        // And: Reward tokens reached the Asset Module outside an interaction.
        // forge-lint: disable-next-item(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(AERO, address(stakedSlipstreamAM), donation, false);
        uint256 rewardsExpected = stakedSlipstreamAM.rewardOf(assetId);

        // When: Calling claimSurplus().
        vm.prank(recipient);
        stakedSlipstreamAM.claimSurplus();

        // Then: The reward of the position is unchanged and paid in full.
        assertEq(stakedSlipstreamAM.rewardOf(assetId), rewardsExpected);
        vm.prank(users.liquidityProvider);
        assertEq(stakedSlipstreamAM.claimReward(assetId), earned);
        assertEq(ERC20(AERO).balanceOf(users.liquidityProvider), earned);
    }

    function testFuzz_Success_claimSurplus_DonationAndBookedAfterInteraction(
        address recipient,
        StakedSlipstreamAM.PositionState memory position,
        uint256 reward,
        uint256 booked,
        uint128 donation,
        int24 tick
    ) public {
        // Given: A staked position with a reward earned.
        (uint256 assetId, uint256 earned) = _initStakedPositionWithEarned(position, tick, reward, recipient);

        // And: Reward tokens reached the Asset Module outside an interaction.
        // forge-lint: disable-next-line(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(AERO, address(stakedSlipstreamAM), donation, false);

        // And: A claim booked a part of the delivery for the recipient.
        booked = bound(booked, 1, earned);
        stakedSlipstreamAM.setBookedAmount(booked);
        vm.prank(users.liquidityProvider);
        assertEq(stakedSlipstreamAM.claimReward(assetId), earned - booked);

        // When: Calling claimSurplus().
        assertEq(stakedSlipstreamAM.claimableSurplus(), donation + booked);
        vm.prank(recipient);
        stakedSlipstreamAM.claimSurplus();

        // Then: The recipient received the donation and the released part.
        assertEq(ERC20(AERO).balanceOf(recipient), donation + booked);
        assertEq(stakedSlipstreamAM.claimableSurplus(), 0);

        // And: The owner keeps the delivery of the position.
        assertEq(ERC20(AERO).balanceOf(users.liquidityProvider), earned - booked);
    }
}
