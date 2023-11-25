/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC20AssetModule_Fuzz_Test } from "./_StandardERC20AssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getKeyFromAsset" of contract "StandardERC20AssetModule".
 */
contract GetKeyFromAsset_StandardERC20AssetModule_Fuzz_Test is StandardERC20AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC20AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getKeyFromAsset(address asset, uint96 assetId) public {
        bytes32 expectedKey = bytes32(abi.encodePacked(uint96(0), asset));
        bytes32 actualKey = erc20AssetModule.getKeyFromAsset(asset, assetId);

        assertEq(actualKey, expectedKey);
    }
}
