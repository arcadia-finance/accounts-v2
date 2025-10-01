/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryL2_Fuzz_Test } from "./_RegistryL2.fuzz.t.sol";
import { RegistryL2 } from "../../../../src/registries/RegistryL2.sol";

/**
 * @notice Fuzz tests for the function "addOracle" of contract "RegistryL2".
 */
contract AddOracle_RegistryL2_Fuzz_Test is RegistryL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addOracle_NonAssetModule(address unprivilegedAddress_) public {
        vm.assume(!registry.isOracleModule(unprivilegedAddress_));

        vm.prank(users.owner);
        vm.expectRevert(RegistryErrors.OnlyOracleModule.selector);
        registry.addOracle();
    }

    function testFuzz_Success_addOracle(address oracleModule_, uint256 oracleCounterLast) public {
        vm.assume(!registry.isOracleModule(oracleModule_));
        vm.prank(users.owner);
        registry.addOracleModule(oracleModule_);

        oracleCounterLast = bound(oracleCounterLast, 0, type(uint80).max);
        registry.setOracleCounter(oracleCounterLast);

        vm.prank(oracleModule_);
        vm.expectEmit();
        emit RegistryL2.OracleAdded(oracleCounterLast, oracleModule_);
        uint256 oracleId = registry.addOracle();

        assertEq(oracleId, oracleCounterLast);
        assertEq(registry.getOracleToOracleModule(oracleId), oracleModule_);
        assertEq(registry.getOracleCounter(), oracleCounterLast + 1);
    }
}
