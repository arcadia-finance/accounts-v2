/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { RegistryGuardianExtension } from "../../../utils/Extensions.sol";
import { BaseGuardian } from "../../../../src/guardians/BaseGuardian.sol";

/**
 * @notice Common logic needed by all "RegistryGuardian" fuzz tests.
 */
abstract contract RegistryGuardian_Fuzz_Test is Fuzz_Test {
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

    RegistryGuardianExtension internal registryGuardian;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        registryGuardian = new RegistryGuardianExtension();
        registryGuardian.changeGuardian(users.guardian);
        vm.stopPrank();

        vm.warp(60 days);
    }

    /*////////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function setFlags(Flags memory flags) internal {
        registryGuardian.setFlags(flags.withdrawPaused, flags.depositPaused);
    }
}
