/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, ERC20Mock, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "rewardsOf" of contract "WrappedAM".
 */
contract RewardsOf_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_rewardsOf(
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address[2] calldata rewards,
        address underlyingAsset,
        uint128 totalWrapped,
        address asset,
        uint96 positionId
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

        // And : Account has a non-zero balance
        vm.assume(positionState_.amountWrapped > 0);

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            Utils.castArrayStaticToDynamic(rewards),
            positionId,
            totalWrapped_,
            underlyingAsset
        );

        // When : Calling rewardsOf()
        uint256[] memory currentRewardsClaimable = wrappedAM.rewardsOf(positionId);

        // Then : It should return the correct value
        for (uint256 i; i < 2; ++i) {
            uint256 deltaRewardGlobal = assetAndRewardState_[i].currentRewardGlobal;
            uint128 rewardPerToken;
            unchecked {
                rewardPerToken = assetAndRewardState_[i].lastRewardPerTokenGlobal
                    + uint128(deltaRewardGlobal.mulDivDown(1e18, totalWrapped_));
            }
            uint128 deltaRewardPerToken;
            unchecked {
                deltaRewardPerToken = rewardPerToken - positionStatePerReward_[i].lastRewardPerTokenPosition;
            }
            uint256 currentRewardPosition = positionStatePerReward_[i].lastRewardPosition
                + uint256(positionState_.amountWrapped).mulDivDown(deltaRewardPerToken, 1e18);

            assertEq(currentRewardsClaimable[i], currentRewardPosition);
        }
    }

    function testFuzz_Success_rewardsOf_WithExtraRewardNotAccountedAsCollateral(
        AbstractWrappedAM_Fuzz_Test.WrappedAMAssetAndRewardStateGlobal[2] memory assetAndRewardState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionState memory positionState,
        AbstractWrappedAM_Fuzz_Test.WrappedAMPositionStatePerReward[2] memory positionStatePerReward,
        address[2] calldata rewards,
        address underlyingAsset,
        uint128 totalWrapped,
        address asset,
        uint96 positionId
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

        // And : Account has a non-zero balance
        vm.assume(positionState_.amountWrapped > 0);

        // Stack too deep
        address[] memory rewards_ = Utils.castArrayStaticToDynamic(rewards);
        address underlyingAssetStack = underlyingAsset;

        // And : State is persisted
        setWrappedAMState(
            assetAndRewardState_,
            positionState_,
            positionStatePerReward_,
            asset,
            rewards_,
            positionId,
            totalWrapped_,
            underlyingAssetStack
        );

        // And : An additional reward is added to the AM for the same asset
        // And : maxRewardsPerAsset should now be set to 3
        vm.prank(users.creatorAddress);
        wrappedAM.setMaxRewardsPerAsset(3);
        address[] memory newReward = new address[](1);
        newReward[0] = address(new ERC20Mock("Reward", "RWD", 18));
        address customAsset = wrappedAM.addAsset(asset, newReward);

        // Stack too deep
        uint128 positionAmountStack = positionState_.amountWrapped;

        // And : Rewards are claimable by AM for that specific reward
        // We need an mount to avoid deltaRewardPerToken to overflow uint128.
        uint256 currentRewardGlobalNew = 100 * 1e18;
        wrappedAM.setCurrentRewardBalance(asset, newReward[0], currentRewardGlobalNew);

        // When : Calling rewardsOf()
        uint256[] memory currentRewardsClaimable = wrappedAM.rewardsOf(positionId);

        // Then : It should return an array of length 3
        assertEq(currentRewardsClaimable.length, 3);

        // And : It should return the correct value for exisiting rewards
        for (uint256 i; i < 2; ++i) {
            uint256 deltaRewardGlobal = assetAndRewardState_[i].currentRewardGlobal;
            uint128 rewardPerToken;
            unchecked {
                rewardPerToken = assetAndRewardState_[i].lastRewardPerTokenGlobal
                    + uint128(deltaRewardGlobal.mulDivDown(1e18, totalWrapped_));
            }
            uint128 deltaRewardPerToken;
            unchecked {
                deltaRewardPerToken = rewardPerToken - positionStatePerReward_[i].lastRewardPerTokenPosition;
            }
            uint256 currentRewardPosition = positionStatePerReward_[i].lastRewardPosition
                + uint256(positionAmountStack).mulDivDown(deltaRewardPerToken, 1e18);

            assertEq(currentRewardsClaimable[i], currentRewardPosition);
        }

        // And : It should return correct values for new reward
        uint128 rewardPerToken_;
        unchecked {
            rewardPerToken_ = uint128(currentRewardGlobalNew.mulDivDown(1e18, totalWrapped_));
        }
        uint256 currentRewardPosition_ = uint256(positionState_.amountWrapped).mulDivDown(rewardPerToken_, 1e18);

        assertEq(currentRewardPosition_, currentRewardsClaimable[2]);
    }
}
