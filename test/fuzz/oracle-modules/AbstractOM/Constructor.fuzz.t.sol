/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractOM_Fuzz_Test } from "./_AbstractOM.fuzz.t.sol";

import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AbstractOM".
 */
contract Constructor_AbstractOM_Fuzz_Test is AbstractOM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address registry_) public {
        vm.startPrank(users.creatorAddress);
        OracleModuleMock oracleModule_ = new OracleModuleMock(registry_);
        vm.stopPrank();

        assertEq(oracleModule_.REGISTRY(), registry_);
    }
}
