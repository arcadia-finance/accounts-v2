/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { NativeTokenAM_Fuzz_Test } from "./_NativeTokenAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getAssetFromKey" of contract "NativeTokenAM".
 */
contract GetAssetFromKey_NativeTokenAM_Fuzz_Test is NativeTokenAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        NativeTokenAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAssetFromKey(address asset, uint96 assetId) public {
        bytes32 key = bytes32(abi.encodePacked(assetId, asset));
        (address actualAsset, uint256 actualAssetId) = nativeTokenAM.getAssetFromKey(key);

        assertEq(actualAsset, asset);
        assertEq(actualAssetId, 0);
    }
}
