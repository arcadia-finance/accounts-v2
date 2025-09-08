/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";
import { RegistryL1 } from "../../../../src/registries/RegistryL1.sol";

/**
 * @notice Fuzz tests for the function "addOracle" of contract "RegistryL1".
 */
contract AddOracle_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addOracle_NonAssetModule(address unprivilegedAddress_) public {
        vm.assume(!registry_.isOracleModule(unprivilegedAddress_));

        vm.prank(users.owner);
        vm.expectRevert(RegistryErrors.OnlyOracleModule.selector);
        registry_.addOracle();
    }

    function testFuzz_Success_addOracle(address oracleModule_, uint256 oracleCounterLast) public {
        vm.assume(!registry_.isOracleModule(oracleModule_));
        vm.prank(users.owner);
        registry_.addOracleModule(oracleModule_);

        oracleCounterLast = bound(oracleCounterLast, 0, type(uint80).max);
        registry_.setOracleCounter(oracleCounterLast);

        vm.prank(oracleModule_);
        vm.expectEmit();
        emit RegistryL1.OracleAdded(oracleCounterLast, oracleModule_);
        uint256 oracleId = registry_.addOracle();

        assertEq(oracleId, oracleCounterLast);
        assertEq(registry_.getOracleToOracleModule(oracleId), oracleModule_);
        assertEq(registry_.getOracleCounter(), oracleCounterLast + 1);
    }
}
