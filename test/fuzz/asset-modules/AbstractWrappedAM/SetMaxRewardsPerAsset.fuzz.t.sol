/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setMaxRewardsPerAsset" of contract "WrappedAM".
 */
contract setMaxRewardsPerAsset_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_revert_setMaxRewardsPerAsset_MaxRewardsReached(uint8 maxRewards) public {
        // Given : maxRewards is higher than MAX_REWARDS
        maxRewards = uint8(bound(maxRewards, wrappedAM.MAX_REWARDS() + 1, type(uint8).max));

        vm.startPrank(users.creatorAddress);
        // When : calling setMaxRewardsPerAsset()
        // Then : It should revert
        vm.expectRevert(WrappedAM.MaxRewardsReached.selector);
        wrappedAM.setMaxRewardsPerAsset(maxRewards);
        vm.stopPrank();
    }

    function testFuzz_revert_setMaxRewardsPerAsset_NotOwner(uint8 maxRewards, address random) public {
        // Given : caller is not the owner
        vm.assume(random != users.creatorAddress);

        vm.startPrank(random);
        // When : calling setMaxRewardsPerAsset()
        // Then : It should revert
        vm.expectRevert("UNAUTHORIZED");
        wrappedAM.setMaxRewardsPerAsset(maxRewards);
        vm.stopPrank();
    }

    function testFuzz_revert_setMaxRewardsPerAsset_IncreaseOnly(uint8 maxRewards, uint8 lowerMaxRewards) public {
        // Given : lowerMaxRewards should be smaller than maxRewards
        maxRewards = uint8(bound(maxRewards, 1, wrappedAM.MAX_REWARDS()));
        lowerMaxRewards = uint8(bound(lowerMaxRewards, 0, maxRewards - 1));

        // And : An initial maxRewards amount is set
        vm.startPrank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(maxRewards);

        // When : Setting a new maxRewards < maxRewards
        // Then : It should revert
        vm.expectRevert(WrappedAM.IncreaseRewardsOnly.selector);
        wrappedAM.setMaxRewardsPerAsset(lowerMaxRewards);
        vm.stopPrank();
    }

    function testFuzz_success_setMaxRewardsPerAsset(uint8 maxRewards) public {
        // Given : maxRewards is in allowed range (can't set it to 0)
        maxRewards = uint8(bound(maxRewards, 1, wrappedAM.MAX_REWARDS()));

        // When : calling setMaxRewardsPerAsset()
        vm.startPrank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(maxRewards);

        // Then : Correct value should be set
        assertEq(maxRewards, wrappedAM.maxRewardsPerAsset());
    }
}
