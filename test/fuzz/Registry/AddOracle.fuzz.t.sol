/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { Registry } from "../../../src/Registry.sol";

/**
 * @notice Fuzz tests for the function "addOracle" of contract "Registry".
 */
contract AddOracle_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
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
        emit Registry.OracleAdded(oracleCounterLast, oracleModule_);
        uint256 oracleId = registry.addOracle();

        assertEq(oracleId, oracleCounterLast);
        assertEq(registry.getOracleToOracleModule(oracleId), oracleModule_);
        assertEq(registry.getOracleCounter(), oracleCounterLast + 1);
    }
}
