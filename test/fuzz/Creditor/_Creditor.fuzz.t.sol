/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test } from "../Fuzz.t.sol";

import { CreditorMock } from "../../utils/mocks/creditors/CreditorMock.sol";

/**
 * @notice Common logic needed by all "Creditor" fuzz tests.
 */
abstract contract Creditor_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    CreditorMock internal creditor;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        creditor = new CreditorMock();
    }
}
