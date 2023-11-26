/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";
import { ChainlinkOracleModuleExtension } from "../../../utils/Extensions.sol";
import { OracleModule } from "../../../../src/oracle-modules/AbstractOracleModule.sol";

/**
 * @notice Common logic needed by all "ChainlinkOracleModule" fuzz tests.
 */
abstract contract ChainlinkOracleModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        chainlinkOM = new ChainlinkOracleModuleExtension(address(registryExtension));
        registryExtension.addOracleModule(address(chainlinkOM));
        vm.stopPrank();
    }
}
