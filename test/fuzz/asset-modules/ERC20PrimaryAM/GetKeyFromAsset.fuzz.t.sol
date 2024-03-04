/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20PrimaryAM_Fuzz_Test } from "./_ERC20PrimaryAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getKeyFromAsset" of contract "ERC20PrimaryAM".
 */
contract GetKeyFromAsset_ERC20PrimaryAM_Fuzz_Test is ERC20PrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ERC20PrimaryAM_Fuzz_Test.setUp();
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
