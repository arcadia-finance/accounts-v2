/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { OracleModuleMock } from "../../../utils/mocks/OracleModuleMock.sol";

/**
 * @notice Common logic needed by all "AbstractOracleModule" fuzz tests.
 */
abstract contract AbstractOracleModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    OracleModuleMock internal oracleModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        oracleModule = new OracleModuleMock(address(mainRegistryExtension));
    }
}