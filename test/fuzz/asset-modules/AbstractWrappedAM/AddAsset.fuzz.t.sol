/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "WrappedAM".
 */
contract AddAsset_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_revert_addAsset_RewardsArrayExceedsMaxAllowed(uint8 maxRewards, address asset) public {
        // Given : maxRewards should not exceed max amount
        maxRewards = uint8(bound(maxRewards, 1, wrappedAM.MAX_REWARDS()));
        vm.startPrank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(maxRewards);

        // And : rewards array exceeds maxRewards
        uint8 rewardsLength = maxRewards + 1;
        uint160 j = 1;
        address[] memory rewards_ = new address[](rewardsLength);
        for (uint256 i; i < rewardsLength; ++i) {
            rewards_[i] = address(j);
            j++;
        }

        // When : calling addAsset()
        // Then : it should revert
        address customAsset = getCustomAsset(asset, rewards_);
        vm.expectRevert(WrappedAM.MaxRewardsReached.selector);
        wrappedAM.addAsset(customAsset, asset, rewards_);
    }

    function testFuzz_revert_addAsset_NewRewardAddedForAssetExceedsMaxRewards(uint8 maxRewards, address asset) public {
        // Given : maxRewards should not exceed max amount
        maxRewards = uint8(bound(maxRewards, 1, wrappedAM.MAX_REWARDS()));
        vm.startPrank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(maxRewards);

        // And : An asset is added with max amount of rewards
        uint8 rewardsLength = maxRewards;
        uint160 j = 1;
        address[] memory rewards_ = new address[](rewardsLength);
        for (uint256 i; i < rewardsLength; ++i) {
            rewards_[i] = address(j);
            j++;
        }

        address customAsset = getCustomAsset(asset, rewards_);
        wrappedAM.addAsset(customAsset, asset, rewards_);

        // And : A new customAsset is added that would add a new reward to account for (and exceeding max rewards)
        // As maxRewards is minimum 1, it shouldn't revert due to the rewards array length
        rewards_ = new address[](1);
        rewards_[0] = address(j);

        // When : Adding that new customAsset
        // Then : It should revert
        customAsset = getCustomAsset(asset, rewards_);
        vm.expectRevert(WrappedAM.MaxRewardsReached.selector);
        wrappedAM.addAsset(customAsset, asset, rewards_);
    }

    function testFuzz_success_addAsset_NewAssetWithNoPreviousRewards(
        uint8 maxRewards,
        address asset,
        uint8 rewardsLength
    ) public {
        // Given : maxRewards should not exceed max amount
        maxRewards = uint8(bound(maxRewards, 1, wrappedAM.MAX_REWARDS()));
        vm.startPrank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(maxRewards);

        // And : Rewards array length does not exceed max rewards amount
        rewardsLength = uint8(bound(rewardsLength, 1, maxRewards));
        uint160 j = 1;
        address[] memory rewards = new address[](rewardsLength);
        for (uint256 i; i < rewardsLength; ++i) {
            rewards[i] = address(j);
            j++;
        }

        address customAsset = getCustomAsset(asset, rewards);

        // When : Calling addAsset()
        wrappedAM.addAsset(customAsset, asset, rewards);

        // Then : It should return the correct values
        (bool allowed, address asset_) = wrappedAM.customAssetInfo(customAsset);
        address[] memory rewardsForCustomAsset = wrappedAM.getRewardsForCustomAsset(customAsset);

        assertEq(allowed, true);
        assertEq(asset, asset_);
        for (uint256 i; i < rewards.length; ++i) {
            assertEq(rewards[i], rewardsForCustomAsset[i]);
            assertEq(rewards[i], wrappedAM.rewardsForAsset(asset, i));
        }
    }

    function testFuzz_success_addAsset_ExistingAssetWithNewReward(uint8 maxRewards, address asset, uint8 rewardsLength)
        public
    {
        // Given : maxRewards should not exceed max amount
        maxRewards = uint8(bound(maxRewards, 3, wrappedAM.MAX_REWARDS()));
        vm.startPrank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(maxRewards);

        // And : Rewards array length does not exceed max rewards amount
        rewardsLength = uint8(bound(rewardsLength, 1, maxRewards - 2));
        uint160 j = 1;
        address[] memory rewards = new address[](rewardsLength);
        for (uint256 i; i < rewardsLength; ++i) {
            rewards[i] = address(j);
            j++;
        }

        address customAsset = getCustomAsset(asset, rewards);

        // And : Rewards have already been set of an Asset
        wrappedAM.addAsset(customAsset, asset, rewards);

        // And : We add a new customAsset with 1 exisiting reward for Asset and 1 new reward for Asset
        address[] memory rewards_ = new address[](2);

        // New reward
        rewards_[0] = address(j);
        for (uint256 i; i < rewards.length; ++i) {
            assert(rewards_[0] != rewards[i]);
        }

        // Existing reward
        rewards_[1] = address(j - 1);
        assertEq(rewards_[1], rewards[rewardsLength - 1]);

        address customAsset_ = getCustomAsset(asset, rewards_);

        // When : We add a new customAsset that has 1 new reward (out of the two provided)
        wrappedAM.addAsset(customAsset_, asset, rewards_);

        // Then : It should have added only the new reward to the rewardsForAsset array
        assertEq(wrappedAM.rewardsForAsset(asset, rewards.length), rewards_[0]);
        // And : all other rewards didn't change
        for (uint256 i; i < rewards.length; ++i) {
            assertEq(rewards[i], wrappedAM.rewardsForAsset(asset, i));
        }
    }
}
