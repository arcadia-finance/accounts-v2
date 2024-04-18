/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "getRewardBalances" of contract "WrappedAM".
 */
contract GetRewardBalances_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_getRewardBalances_NonZeroTotalStaked_OverflowDeltaRewardPerToken_MulDivDown(
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

        // Given : totalWrapped is greater than 0
        vm.assume(totalWrapped_ > 0);

        for (uint256 i; i < positionStatePerReward_.length; ++i) {
            // And : lastRewardPerTokenPosition is greater than 0
            positionStatePerReward_[i].lastRewardPerTokenPosition = 0;
            // And : deltaRewardPerToken mulDivDown overflows.
            assetAndRewardState_[i].currentRewardGlobal =
                bound(assetAndRewardState_[i].currentRewardGlobal, type(uint256).max / 1e18, type(uint256).max);
        }

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

        // When: Calling _getRewardBalances().
        // Then: transaction reverts in safe cast.
        vm.expectRevert(bytes(""));
        wrappedAM.getRewardBalances(tokenId);
    }

    function testFuzz_Revert_getRewardBalances_NonZeroTotalStaked_OverflowDeltaRewardPerToken_SafeCast(
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

        // Given : totalWrapped is greater than 0
        vm.assume(totalWrapped_ > 0);

        for (uint256 i; i < positionStatePerReward_.length; ++i) {
            // And : lastRewardPerTokenPosition is greater than 0
            positionStatePerReward_[i].lastRewardPerTokenPosition = 0;
            // And: deltaRewardPerToken is bigger as type(uint128).max (overflow safeCastTo128).
            uint256 lowerBound = (totalWrapped_ < 1e18)
                ? uint256(type(uint128).max).mulDivUp(totalWrapped_, 1e18)
                : uint256(type(uint128).max) * totalWrapped_ / 1e18 + totalWrapped_;
            assetAndRewardState_[i].currentRewardGlobal =
                bound(assetAndRewardState_[i].currentRewardGlobal, lowerBound, type(uint256).max);
        }

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

        // When: Calling _getRewardBalances().
        // Then: transaction reverts in safe cast.
        vm.expectRevert(bytes(""));
        wrappedAM.getRewardBalances(tokenId);
    }

    // TODO: see in which case this one fails
    function testFuzz_Revert_getRewardBalances_NonZeroTotalStaked_OverflowDeltaRewardPosition(
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

        // Given: More than 1e18 gwei is staked.
        totalWrapped_ = uint128(bound(totalWrapped_, 1e18 + 1, type(uint128).max));

        for (uint256 i; i < positionStatePerReward_.length; ++i) {
            // And: totalWrapped should be >= to amountWrapped for position (invariant).
            positionState_.amountWrapped = uint128(bound(positionState_.amountWrapped, 1e18 + 1, totalWrapped_));

            // And: deltaRewardPerToken is smaller or equal as type(uint128).max (no overflow safeCastTo128).
            assetAndRewardState_[i].currentRewardGlobal =
                bound(assetAndRewardState_[i].currentRewardGlobal, 1, uint256(type(uint128).max) * totalWrapped_ / 1e18);

            // And : Calculate the new rewardPerTokenGlobal.
            uint256 deltaRewardPerToken = assetAndRewardState_[i].currentRewardGlobal * 1e18 / totalWrapped_;
            uint128 currentRewardPerTokenGlobal;
            unchecked {
                currentRewardPerTokenGlobal =
                    assetAndRewardState_[i].lastRewardPerTokenGlobal + uint128(deltaRewardPerToken);
            }
            // And: deltaReward of the position is bigger than type(uint128).max (overflow).
            unchecked {
                deltaRewardPerToken =
                    currentRewardPerTokenGlobal - positionStatePerReward_[i].lastRewardPerTokenPosition;
            }
            deltaRewardPerToken =
                bound(deltaRewardPerToken, type(uint128).max * uint256(1e18 + 1) / totalWrapped_, type(uint128).max);
            unchecked {
                positionStatePerReward_[i].lastRewardPerTokenPosition =
                    currentRewardPerTokenGlobal - uint128(deltaRewardPerToken);
            }

            // And : lastRewardPertokenPosition should be greater than 0
            vm.assume(positionStatePerReward_[i].lastRewardPerTokenPosition > 0);
        }

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

        // When: Calling _getRewardBalances().
        // Then: transaction reverts in safe cast.
        vm.expectRevert(bytes(""));
        wrappedAM.getRewardBalances(tokenId);
    }

    // TODO: revert for overflowLastRewardPosition
    // TODO: success for ZeroTotalStaked

    function testFuzz_success_getRewardBalances_nonZeroTotalWrapped_nonZeroLastRewardPerTokenPosition(
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

        // And : totalWrapped is greater than 0
        vm.assume(totalWrapped_ > 0);
        // And : lastRewardPerTokenPosition is greater than 0
        for (uint256 i; i < positionStatePerReward_.length; ++i) {
            vm.assume(positionStatePerReward_[i].lastRewardPerTokenPosition > 0);
        }

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

        (
            uint128[] memory lastRewardPerTokenGlobalArr,
            WrappedAM.RewardStatePosition[] memory rewardStatePositionArr,
            address[] memory activeRewards_
        ) = wrappedAM.getRewardBalances(tokenId);

        // Then : It should return the correct values
        assertEq(activeRewards_.length, 2);
        assertEq(activeRewards_[0], rewards[0]);
        assertEq(activeRewards_[1], rewards[1]);

        for (uint256 i; i < rewards.length; ++i) {
            // Stack too deep
            uint128 initialRewardPosition = positionStatePerReward_[i].lastRewardPosition;
            address assetStack = asset;

            uint256 deltaReward = assetAndRewardState_[i].currentRewardGlobal;
            uint128 rewardPerToken;
            unchecked {
                rewardPerToken = assetAndRewardState_[i].lastRewardPerTokenGlobal
                    + uint128(deltaReward.mulDivDown(1e18, totalWrapped_));
            }
            uint128 deltaRewardPerToken;
            unchecked {
                deltaRewardPerToken = rewardPerToken - positionStatePerReward_[i].lastRewardPerTokenPosition;
            }
            deltaReward = uint256(positionState_.amountWrapped).mulDivDown(deltaRewardPerToken, 1e18);

            assertEq(rewardStatePositionArr[i].lastRewardPerTokenPosition, rewardPerToken);
            assertEq(rewardStatePositionArr[i].lastRewardPosition, initialRewardPosition + deltaReward);
            assertEq(lastRewardPerTokenGlobalArr[i], rewardPerToken);
            assertEq(wrappedAM.assetToTotalWrapped(assetStack), totalWrapped_);
        }
    }

    function testFuzz_success_getRewardBalances_nonZeroTotalWrapped_ZeroLastRewardPerTokenPosition(
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

        // And : totalWrapped is greater than 0
        vm.assume(totalWrapped_ > 0);
        // And : lastRewardPerTokenPosition is greater than 0
        for (uint256 i; i < positionStatePerReward_.length; ++i) {
            positionStatePerReward_[i].lastRewardPerTokenPosition = 0;
        }

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

        (
            uint128[] memory lastRewardPerTokenGlobalArr,
            WrappedAM.RewardStatePosition[] memory rewardStatePositionArr,
            address[] memory activeRewards_
        ) = wrappedAM.getRewardBalances(tokenId);

        // Then : It should return the correct values
        assertEq(activeRewards_.length, 2);

        for (uint256 i; i < rewards.length; ++i) {
            // Stack too deep
            uint128 initialRewardPosition = positionStatePerReward_[i].lastRewardPosition;
            address assetStack = asset;

            uint256 deltaReward = assetAndRewardState_[i].currentRewardGlobal;
            uint128 rewardPerToken;
            unchecked {
                rewardPerToken = assetAndRewardState_[i].lastRewardPerTokenGlobal
                    + uint128(deltaReward.mulDivDown(1e18, totalWrapped_));
            }

            assertEq(rewardStatePositionArr[i].lastRewardPerTokenPosition, rewardPerToken);
            assertEq(rewardStatePositionArr[i].lastRewardPosition, initialRewardPosition);
            assertEq(lastRewardPerTokenGlobalArr[i], rewardPerToken);
            assertEq(wrappedAM.assetToTotalWrapped(assetStack), totalWrapped_);
        }
    }
}
