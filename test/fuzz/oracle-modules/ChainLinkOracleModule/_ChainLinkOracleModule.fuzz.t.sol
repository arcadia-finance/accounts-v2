/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";
import { ChainLinkOracleModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "ChainLinkOracleModule" fuzz tests.
 */
abstract contract ChainLinkOracleModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ChainLinkOracleModuleExtension internal chainlinkOM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        chainlinkOM = new ChainLinkOracleModuleExtension(address(mainRegistryExtension));
        mainRegistryExtension.addOracleModule(address(chainlinkOM));
        vm.stopPrank();
    }
}
