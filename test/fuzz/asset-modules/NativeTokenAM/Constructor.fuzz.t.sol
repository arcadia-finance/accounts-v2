/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { NativeTokenAM_Fuzz_Test } from "./_NativeTokenAM.fuzz.t.sol";
import { NativeTokenAMExtension } from "../../../utils/extensions/NativeTokenAMExtension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "NativeTokenAM".
 */
contract Constructor_NativeTokenAM_Fuzz_Test is NativeTokenAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        NativeTokenAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.prank(users.owner);
        NativeTokenAMExtension nativeTokenAM_ = new NativeTokenAMExtension(registry_);

        assertEq(nativeTokenAM_.REGISTRY(), registry_);
        assertEq(nativeTokenAM_.ASSET_TYPE(), 4);
    }
}
