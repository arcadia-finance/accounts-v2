/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { NativeTokenAMExtension } from "../../../utils/extensions/NativeTokenAMExtension.sol";

/**
 * @notice Common logic needed by all "NativeTokenAM" fuzz tests.
 */
abstract contract NativeTokenAM_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes32 internal oraclesNativeTokenToUsd;

    NativeTokenAMExtension internal nativeTokenAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        nativeTokenAM = new NativeTokenAMExtension(address(registry));
        registry.addAssetModule(address(nativeTokenAM));
        vm.stopPrank();

        oraclesNativeTokenToUsd = BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken1ToUsdArr);
    }
}
