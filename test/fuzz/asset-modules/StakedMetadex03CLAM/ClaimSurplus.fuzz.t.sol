/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";

/**
 * @notice Fuzz tests for the function "claimSurplus" of contract "StakedMetadex03CLAM".
 */
contract ClaimSurplus_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_claimSurplus_NothingToClaim(address recipient) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: Nothing reached the Asset Module.
        assertEq(stakedMetadex03CLAM.claimableSurplus(), 0);

        // When: Calling claimSurplus().
        vm.recordLogs();
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();

        // Then: Nothing is emitted and nothing is transferred.
        assertEq(vm.getRecordedLogs().length, 0);
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), 0);
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimSurplus_Leaf_Donation(uint128 donation, address recipient) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: Reward tokens reached the Asset Module outside an interaction.
        // forge-lint: disable-next-line(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(rewardToken, address(stakedMetadex03CLAM), donation);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), donation);

        // When: Calling claimSurplus().
        // Then: The SurplusClaimed event is emitted.
        vm.expectEmit(address(stakedMetadex03CLAM));
        emit StakedSlipstreamAM.SurplusClaimed(surplusRecipient, donation);
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();

        // And: The recipient received it and nothing is left claimable.
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), donation);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_Root_Donation(uint128 donation, address recipient) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The protocol is staged on the root chain.
        _stageRoot();

        // And: Reward tokens reached the Asset Module outside an interaction.
        // forge-lint: disable-next-line(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(rootToken, address(stakedMetadex03CLAM), donation);

        // When: Calling claimSurplus().
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();

        // Then: The recipient received it and nothing is left claimable.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), donation);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_Root_HeldReleasedByLp(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A sub-floor claim on the root chain left the reward with the emissions handler.
        emissions = bound(emissions, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 held = _initRootHeldRewards(position, emissions, tick);
        vm.assume(held > 0);

        // And: An unrelated party released the handler's hold to this contract.
        deal(rootToken, address(stakedMetadex03CLAM), held);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), held);

        // When: Calling claimSurplus().
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();

        // Then: The recipient received the released hold.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), held);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), 0);
    }

    function testFuzz_Success_claimSurplus_PositionRewardUntouched(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        uint128 donation,
        int24 tick
    ) public {
        // Given: A staked position whose emissions exceed the wei its share can round away.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGt(rewardsExpected, 0);

        // And: Reward tokens reached the Asset Module outside an interaction.
        // forge-lint: disable-next-line(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(rewardToken, address(stakedMetadex03CLAM), donation);

        // When: Calling claimSurplus().
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();

        // Then: The reward of the position is unchanged and paid in full.
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), rewardsExpected);
        vm.prank(users.liquidityProvider);
        assertEq(stakedMetadex03CLAM.claimReward(assetId), rewardsExpected);
        assertEq(ERC20(rewardToken).balanceOf(users.liquidityProvider), rewardsExpected);
    }

    function testFuzz_Success_claimSurplus_Root_DonationAndHeldAfterInteraction(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        uint128 donation,
        int24 tick,
        address ownerSecond,
        address recipient
    ) public canReceiveERC721(ownerSecond) {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A sub-floor claim on the root chain left the reward with the emissions handler.
        position = _givenPositionStakedTwice(position);
        emissionsFirst = bound(emissionsFirst, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 held = _initRootHeldRewards(position, emissionsFirst, tick);
        vm.assume(held > 0);

        // And: Reward tokens reached the Asset Module outside an interaction.
        // forge-lint: disable-next-line(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(rootToken, address(stakedMetadex03CLAM), donation);

        // And: A second owner staked a position over the same range in the same gauge.
        _givenValidSecondOwner(ownerSecond);
        uint256 assetId = _stakePositionAs(position, ownerSecond);

        // And: Fresh emissions bring the reward of that position over the redeem floor.
        emissionsSecond = bound(emissionsSecond, MIN_REDEEM_AMOUNT, MAX_BASE_RATE - MIN_REDEEM_AMOUNT);
        addEmissionsToGauge(address(gauge), emissionsSecond);
        vm.warp(block.timestamp + 1);
        uint256 ownReward = gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId))
            - gauge.deferredEmissions(address(stakedMetadex03CLAM));
        vm.assume(ownReward >= MIN_REDEEM_AMOUNT);

        // And: That owner claims, which releases the handler's hold with its reward.
        vm.prank(ownerSecond);
        assertEq(stakedMetadex03CLAM.claimReward(assetId), ownReward);

        // When: Calling claimSurplus().
        assertEq(stakedMetadex03CLAM.claimableSurplus(), donation + held);
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();

        // Then: The recipient received the donation and the released hold.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), donation + held);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), 0);

        // And: The owner keeps the reward of its position.
        assertEq(ERC20(rootToken).balanceOf(ownerSecond), ownReward);
    }
}
