/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { RegistryL1_Fuzz_Test, RegistryErrors } from "./_RegistryL1.fuzz.t.sol";

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
        RegistryL1Extension registry__ = new RegistryL1Extension(address(factory));

        assertEq(registry__.FACTORY(), address(factory));
    }
}
