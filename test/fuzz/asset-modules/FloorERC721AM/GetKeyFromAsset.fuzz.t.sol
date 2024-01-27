/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC721AM_Fuzz_Test } from "./_FloorERC721AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getKeyFromAsset" of contract "FloorERC721AM".
 */
contract GetKeyFromAsset_FloorERC721AM_Fuzz_Test is FloorERC721AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getKeyFromAsset(address asset, uint96 assetId) public {
        bytes32 expectedKey = bytes32(abi.encodePacked(uint96(0), asset));
        bytes32 actualKey = floorERC721AM.getKeyFromAsset(asset, assetId);

        assertEq(actualKey, expectedKey);
    }
}
