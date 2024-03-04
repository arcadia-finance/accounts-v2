/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractAM_Fuzz_Test } from "./_AbstractAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getKeyFromAsset" of contract "AbstractAssetModule".
 */
contract GetKeyFromAsset_AbstractAM_Fuzz_Test is AbstractAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getKeyFromAsset(address asset, uint96 assetId) public {
        bytes32 expectedKey = bytes32(abi.encodePacked(assetId, asset));
        bytes32 actualKey = assetModule.getKeyFromAsset(asset, assetId);

        assertEq(actualKey, expectedKey);
    }
}
