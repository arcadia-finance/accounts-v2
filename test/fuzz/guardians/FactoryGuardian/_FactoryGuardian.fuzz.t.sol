/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../../Fuzz.t.sol";

import { FactoryGuardianExtension } from "../../../utils/Extensions.sol";
import { BaseGuardian } from "../../../../src/guardians/BaseGuardian.sol";

/**
 * @notice Common logic needed by all "FactoryGuardian" fuzz tests.
 */
abstract contract FactoryGuardian_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bool createPaused;

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
    function setFlags(bool flag) internal {
        factoryGuardian.setFlags(flag);
    }
}
