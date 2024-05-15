/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, WrappedAM, ERC20Mock } from "./_AbstractWrappedAM.fuzz.t.sol";
import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssetsAmounts" of contract "WrappedAM".
 */
contract GetUnderlyingAssetsAmounts_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_getUnderlyingAssetsAmounts_AmountNotZero_SameRewardsForAssetAndCustomAsset(
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address asset,
        address[2] calldata rewards,
        uint96 tokenId,
        uint128 totalWrapped,
        address underlyingAsset
    ) public {
        // Given : Valid state
        (
            AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[] memory positionStatePerReward_,
            uint128 totalWrapped_
        ) = givenValidWrappedAMState(
            castArrayStaticToDynamicAssetAndReward(assetAndRewardState),
            positionState,
            castArrayStaticToDynamicPositionPerReward(positionStatePerReward),
            totalWrapped
        );

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            Utils.castArrayStaticToDynamic(rewards),
            tokenId,
            totalWrapped_,
            underlyingAsset
        );

        uint256 positionAmount = positionState_.amountWrapped;
        // And: amount is greater than 0
        vm.assume(positionAmount > 0);

        // When : Calling getUnderlyingAssetsAmounts()
        bytes32[] memory emptyArr;
        bytes32 assetKey = wrappedAM.getKeyFromAsset(address(wrappedAM), tokenId);
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            wrappedAM.getUnderlyingAssetsAmounts(address(0), assetKey, positionAmount, emptyArr);

        // Then : It should return the correct values
        uint256[] memory claimableRewards = wrappedAM.rewardsOf(tokenId);
        // 1 Underlying asset + 2 rewards
        assertEq(underlyingAssetsAmounts.length, 3);
        assertEq(underlyingAssetsAmounts[0], positionAmount);
        assertEq(underlyingAssetsAmounts[1], claimableRewards[0]);
        assertEq(underlyingAssetsAmounts[2], claimableRewards[1]);

        // And: No rateUnderlyingAssetsToUsd are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_success_getUnderlyingAssetsAmounts_AmountNotZero_RewardsDifferForAssetAndCustomAsset(
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address asset,
        address[2] calldata rewards,
        uint96 tokenId,
        uint128 totalWrapped,
        address underlyingAsset,
        uint128 position2Amount
    ) public {
        // Given : tokenId not equal to 2 (we use tokenId 2 further in the test)
        vm.assume(tokenId != 2);

        // And : position2Amount is greater than  0
        vm.assume(position2Amount > 0);

        // And : Valid state
        (
            AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[] memory positionStatePerReward_,
            uint128 totalWrapped_
        ) = givenValidWrappedAMState(
            castArrayStaticToDynamicAssetAndReward(assetAndRewardState),
            positionState,
            castArrayStaticToDynamicPositionPerReward(positionStatePerReward),
            totalWrapped
        );

        // Given : totalWrapped is 0 (objective of the test is not to test _getRewardBalances(), but that the position and reward amounts are returned in the correct order)
        totalWrapped_ = 0;

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            Utils.castArrayStaticToDynamic(rewards),
            tokenId,
            totalWrapped_,
            underlyingAsset
        );

        // And : Set maxRewardsPerAsset to 3 (2 existing + 1 new reward)
        vm.startPrank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(3);

        // And : Add a new custom Asset
        address newReward = address(new ERC20Mock("Reward", "RWD", 18));
        address[] memory rewardsForCustomAsset = new address[](2);
        // New reward
        rewardsForCustomAsset[0] = newReward < rewards[0] ? newReward : rewards[0];
        // Exisiting reward
        rewardsForCustomAsset[1] = newReward > rewards[0] ? newReward : rewards[0];

        setAllowedInRegistry(rewardsForCustomAsset[0]);
        setAllowedInRegistry(rewardsForCustomAsset[1]);

        address customAsset = wrappedAM.addAsset(asset, rewardsForCustomAsset);

        // Stack too deep
        uint256 position2AmountStack = position2Amount;

        // And : Set rewards for new position Id
        wrappedAM.setLastRewardPosition(2, newReward, 1e18);
        wrappedAM.setLastRewardPosition(2, rewards[0], 1e6);
        wrappedAM.setAmountWrappedForPosition(2, position2AmountStack);
        wrappedAM.setCustomAssetForPosition(customAsset, 2);

        // Stack too deep
        address rewards0Stack = rewards[0];

        // When : Calling getUnderlyingAssetsAmounts()
        bytes32[] memory emptyArr;
        bytes32 assetKey = wrappedAM.getKeyFromAsset(address(wrappedAM), 2);
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            wrappedAM.getUnderlyingAssetsAmounts(address(0), assetKey, position2AmountStack, emptyArr);

        // Then : It should return the correct values
        // 1 Underlying asset + 2 rewards
        assertEq(underlyingAssetsAmounts.length, 3);
        assertEq(underlyingAssetsAmounts[0], position2AmountStack);
        assertEq(underlyingAssetsAmounts[1], newReward < rewards0Stack ? 1e18 : 1e6);
        assertEq(underlyingAssetsAmounts[2], newReward > rewards0Stack ? 1e18 : 1e6);
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_success_getUnderlyingAssetsAmounts_AmountIsZero(
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address asset,
        address[2] calldata rewards,
        uint96 tokenId,
        uint128 totalWrapped,
        address underlyingAsset
    ) public {
        // Given : Valid state
        (
            AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[] memory assetAndRewardState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState_,
            AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[] memory positionStatePerReward_,
            uint128 totalWrapped_
        ) = givenValidWrappedAMState(
            castArrayStaticToDynamicAssetAndReward(assetAndRewardState),
            positionState,
            castArrayStaticToDynamicPositionPerReward(positionStatePerReward),
            totalWrapped
        );

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            Utils.castArrayStaticToDynamic(rewards),
            tokenId,
            totalWrapped_,
            underlyingAsset
        );

        // When : Calling getUnderlyingAssetsAmounts() with 0 amount
        bytes32[] memory emptyArr;
        bytes32 assetKey = wrappedAM.getKeyFromAsset(address(wrappedAM), tokenId);
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            wrappedAM.getUnderlyingAssetsAmounts(address(0), assetKey, 0, emptyArr);

        // Then : It should return the correct values
        assertEq(underlyingAssetsAmounts.length, 3);
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(underlyingAssetsAmounts[2], 0);
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
