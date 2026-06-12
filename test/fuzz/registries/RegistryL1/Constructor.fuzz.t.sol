/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";

import { RegistryL1Extension } from "../../../utils/extensions/RegistryL1Extension.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "RegistryL1".
 */
contract Constructor_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment() public {
        vm.prank(users.owner);
        RegistryL1Extension registry_ = new RegistryL1Extension(users.owner, address(factory));

        assertEq(registry_.FACTORY(), address(factory));
    }
}
