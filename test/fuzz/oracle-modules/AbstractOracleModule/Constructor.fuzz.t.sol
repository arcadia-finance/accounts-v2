/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractOracleModule_Fuzz_Test } from "./_AbstractOracleModule.fuzz.t.sol";

import { OracleModuleMock } from "../../../utils/mocks/OracleModuleMock.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "AbstractOracleModule".
 */
contract Constructor_AbstractOracleModule_Fuzz_Test is AbstractOracleModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment(address mainRegistry_) public {
        vm.startPrank(users.creatorAddress);
        OracleModuleMock oracleModule_ = new OracleModuleMock(
            mainRegistry_
        );
        vm.stopPrank();

        assertEq(oracleModule_.MAIN_REGISTRY(), mainRegistry_);
    }
}
