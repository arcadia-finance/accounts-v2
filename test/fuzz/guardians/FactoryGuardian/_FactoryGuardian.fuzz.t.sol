/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { FactoryGuardianExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "FactoryGuardian" fuzz tests.
 */
abstract contract FactoryGuardian_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct Flags {
        bool createPaused;
        bool liquidatePaused;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    FactoryGuardianExtension internal factoryGuardian;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        factoryGuardian = new FactoryGuardianExtension();
        factoryGuardian.changeGuardian(users.guardian);
        vm.stopPrank();

        vm.warp(60 days);
    }

    /*////////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function setFlags(Flags memory flags) internal {
        factoryGuardian.setFlags(flags.createPaused, flags.liquidatePaused);
    }
}
