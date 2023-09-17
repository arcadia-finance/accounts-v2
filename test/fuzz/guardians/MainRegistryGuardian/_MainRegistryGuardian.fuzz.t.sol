/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { MainRegistryGuardianExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "MainRegistryGuardian" fuzz tests.
 */
abstract contract MainRegistryGuardian_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct Flags {
        bool withdrawPaused;
        bool depositPaused;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    MainRegistryGuardianExtension internal mainRegistryGuardian;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        mainRegistryGuardian = new MainRegistryGuardianExtension();
        mainRegistryGuardian.changeGuardian(users.guardian);
        vm.stopPrank();

        vm.warp(60 days);
    }

    /*////////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function setFlags(Flags memory flags) internal {
        mainRegistryGuardian.setFlags(flags.withdrawPaused, flags.depositPaused);
    }
}
