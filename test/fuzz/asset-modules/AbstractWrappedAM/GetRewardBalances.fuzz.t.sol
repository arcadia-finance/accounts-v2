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

    function testFuzz_success_getRewardBalances_nonZeroTotalWrapped(
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
            uint256[] memory lastRewardPerTokenGlobalArr,
            WrappedAM.RewardStatePosition[] memory rewardStatePositionArr,
            address[] memory activeRewards_
        ) = wrappedAM.getRewardBalances(tokenId);

        // Then : It should return the correct values
        assertEq(activeRewards_.length, 2);

        for (uint256 i; i < rewards.length; ++i) {
            // Stack too deep
            uint128 initialRewardPosition = positionStatePerReward[i].lastRewardPosition;
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
}
