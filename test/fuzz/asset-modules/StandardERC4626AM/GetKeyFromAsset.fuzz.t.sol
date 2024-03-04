/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC4626AM_Fuzz_Test } from "./_StandardERC4626AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getKeyFromAsset" of contract "StandardERC4626AM".
 */
contract GetKeyFromAsset_StandardERC4626AM_Fuzz_Test is StandardERC4626AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getKeyFromAsset(address asset, uint96 assetId) public {
        bytes32 expectedKey = bytes32(abi.encodePacked(uint96(0), asset));
        bytes32 actualKey = erc4626AM.getKeyFromAsset(asset, assetId);

        assertEq(actualKey, expectedKey);
    }
}
