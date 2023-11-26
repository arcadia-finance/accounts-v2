/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addOracleModule" of contract "Registry".
 */
contract AddOracleModule_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addOracleModule_NonOwner(address unprivilegedAddress_, address oracleModule_) public {
        // Given: unprivilegedAddress_ is not users.creatorAddress
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addOracleModule

        // Then: addOracleModule should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        registryExtension.addOracleModule(oracleModule_);
        vm.stopPrank();
    }

    function testFuzz_Revert_addOracleModule_AddExistingOracleModule(address oracleModule_) public {
        // Given: "oracleModule" is previously added.
        vm.assume(!registryExtension.isOracleModule(oracleModule_));
        vm.prank(users.creatorAddress);
        registryExtension.addOracleModule(oracleModule_);

        // When: users.creatorAddress calls addOracleModule for oracleModule.
        // Then: addOracleModule should revert with "MR_APM: OracleMod. not unique"
        vm.prank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.OracleModNotUnique.selector);
        registryExtension.addOracleModule(oracleModule_);
    }

    function testFuzz_Success_addOracleModule(address oracleModule_) public {
        // Given: oracleModule is different from previously deployed oracle modules.
        vm.assume(!registryExtension.isOracleModule(oracleModule_));

        // When: users.creatorAddress calls addOracleModule for oracleModule.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit OracleModuleAdded(oracleModule_);
        registryExtension.addOracleModule(oracleModule_);
        vm.stopPrank();

        // Then: isOracleModule for "oracleModule" should return true
        assertTrue(registryExtension.isOracleModule(oracleModule_));
    }
}
