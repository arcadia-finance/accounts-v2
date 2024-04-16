/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssets" of contract "WrappedAM".
 */
contract GetUnderlyingAssets_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_getUnderlyingAssets(
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

        // When : Calling getUnderlyingAssets()
        bytes32 assetKey = wrappedAM.getKeyFromAsset(address(wrappedAM), tokenId);
        bytes32[] memory underlyingAssetKeys = wrappedAM.getUnderlyingAssets(assetKey);

        // Then : It should return the correct values
        assertEq(underlyingAssetKeys.length, 3);
        assertEq(underlyingAssetKeys[0], wrappedAM.getKeyFromAsset(underlyingAsset, 0));
        assertEq(underlyingAssetKeys[1], wrappedAM.getKeyFromAsset(rewards[0], 0));
        assertEq(underlyingAssetKeys[2], wrappedAM.getKeyFromAsset(rewards[1], 0));
    }
}
