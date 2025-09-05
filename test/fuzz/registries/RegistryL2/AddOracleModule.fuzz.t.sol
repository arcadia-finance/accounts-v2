/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL2_Fuzz_Test, RegistryErrors } from "./_RegistryL2.fuzz.t.sol";

import { RegistryL2 } from "../../../../src/registries/RegistryL2.sol";

/**
 * @notice Fuzz tests for the function "addOracleModule" of contract "RegistryL2".
 */
contract AddOracleModule_RegistryL2_Fuzz_Test is RegistryL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addOracleModule_NonOwner(address unprivilegedAddress_, address oracleModule_) public {
        // Given: unprivilegedAddress_ is not users.owner
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addOracleModule

        // Then: addOracleModule should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        registry.addOracleModule(oracleModule_);
        vm.stopPrank();
    }

    function testFuzz_Revert_addOracleModule_AddExistingOracleModule(address oracleModule_) public {
        // Given: "oracleModule" is previously added.
        vm.assume(!registry.isOracleModule(oracleModule_));
        vm.prank(users.owner);
        registry.addOracleModule(oracleModule_);

        // When: users.owner calls addOracleModule for oracleModule.
        // Then: addOracleModule should revert with "MR_APM: OracleMod. not unique"
        vm.prank(users.owner);
        vm.expectRevert(RegistryErrors.OracleModNotUnique.selector);
        registry.addOracleModule(oracleModule_);
    }

    function testFuzz_Success_addOracleModule(address oracleModule_) public {
        // Given: oracleModule is different from previously deployed oracle modules.
        vm.assume(!registry.isOracleModule(oracleModule_));

        // When: users.owner calls addOracleModule for oracleModule.
        vm.startPrank(users.owner);
        vm.expectEmit(true, true, true, true);
        emit RegistryL2.OracleModuleAdded(oracleModule_);
        registry.addOracleModule(oracleModule_);
        vm.stopPrank();

        // Then: isOracleModule for "oracleModule" should return true
        assertTrue(registry.isOracleModule(oracleModule_));
    }
}
