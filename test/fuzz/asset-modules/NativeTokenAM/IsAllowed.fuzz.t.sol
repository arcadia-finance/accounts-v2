/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { NativeTokenAM_Fuzz_Test } from "./_NativeTokenAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "NativeTokenAM".
 */
contract IsAllowed_NativeTokenAM_Fuzz_Test is NativeTokenAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        NativeTokenAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Positive(address asset, uint256 assetId) public {
        vm.startPrank(users.owner);
        nativeTokenAM.addAsset(asset, oraclesNativeTokenToUsd);

        assertTrue(nativeTokenAM.isAllowed(asset, assetId));
    }

    function testFuzz_Success_isAllowed_Negative(address randomAsset, uint256 assetId) public {
        assertFalse(nativeTokenAM.isAllowed(randomAsset, assetId));
    }
}
