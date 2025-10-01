/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLibExtension } from "../../utils/extensions/AssetValuationLibExtension.sol";
import { Fuzz_Test } from "../Fuzz.t.sol";

/**
 * @notice Common logic needed by all "AssetValuationLib" fuzz tests.
 */
abstract contract AssetValuationLib_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AssetValuationLibExtension internal assetValuationLib;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        assetValuationLib = new AssetValuationLibExtension();
    }
}
