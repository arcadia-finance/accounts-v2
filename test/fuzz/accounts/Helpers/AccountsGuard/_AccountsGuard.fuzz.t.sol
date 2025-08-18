/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountsGuardExtension } from "../../../../utils/extensions/AccountsGuardExtension.sol";
import { Fuzz_Test } from "../../../Fuzz.t.sol";

/**
 * @notice Common logic needed by all "AccountsGuard" fuzz tests.
 */
abstract contract AccountsGuard_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AccountsGuardExtension internal accountsGuard;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.prank(users.owner);
        accountsGuard = new AccountsGuardExtension(users.owner, address(factory));
    }

    /* ///////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
}
