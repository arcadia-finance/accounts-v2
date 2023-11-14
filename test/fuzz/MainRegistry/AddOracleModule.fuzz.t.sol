/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addOracleModule" of contract "MainRegistry".
 */
contract AddOracleModule_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
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
        mainRegistryExtension.addOracleModule(oracleModule_);
        vm.stopPrank();
    }

    function testFuzz_Revert_addOracleModule_AddExistingPricingModule(address oracleModule_) public {
        // Given: "oracleModule" is previously added.
        vm.assume(!mainRegistryExtension.isOracleModule(oracleModule_));
        vm.prank(users.creatorAddress);
        mainRegistryExtension.addOracleModule(oracleModule_);

        // When: users.creatorAddress calls addOracleModule for oracleModule.
        // Then: addOracleModule should revert with "MR_APM: OracleMod. not unique"
        vm.prank(users.creatorAddress);
        vm.expectRevert("MR_AOM: OracleMod. not unique");
        mainRegistryExtension.addOracleModule(oracleModule_);
    }

    function testFuzz_Success_addOracleModule(address oracleModule_) public {
        // Given: oracleModule is different from previously deployed oracle modules.
        vm.assume(!mainRegistryExtension.isOracleModule(oracleModule_));

        // When: users.creatorAddress calls addOracleModule for oracleModule.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit OracleModuleAdded(oracleModule_);
        mainRegistryExtension.addOracleModule(oracleModule_);
        vm.stopPrank();

        // Then: isOracleModule for "oracleModule" should return true
        assertTrue(mainRegistryExtension.isOracleModule(oracleModule_));
    }
}
