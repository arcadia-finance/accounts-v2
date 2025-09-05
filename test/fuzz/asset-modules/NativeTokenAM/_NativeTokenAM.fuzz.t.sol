/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";

/**
 * @notice Common logic needed by all "NativeTokenAM" fuzz tests.
 */
abstract contract NativeTokenAM_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes32 internal oraclesNativeTokenToUsd;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        deployNativeTokenAM();

        oraclesNativeTokenToUsd = BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken1ToUsdArr);
    }
}
