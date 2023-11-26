/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../../../../lib/forge-std/src/Test.sol";

import { BitPackingLibExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "BitPackingLib" fuzz tests.
 */
abstract contract BitPackingLib_Fuzz_Test is Test {
    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    BitPackingLibExtension internal bitPackingLib;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual {
        bitPackingLib = new BitPackingLibExtension();
    }
}
