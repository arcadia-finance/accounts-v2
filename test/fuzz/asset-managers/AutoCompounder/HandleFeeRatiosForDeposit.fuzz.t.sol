/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounderExtension } from "./_AutoCompounder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "handleFeeRatiosForDeposit" of contract "AutoCompounder".
 */
contract HandleFeeRatiosForDeposit_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_success_currentTickGreaterThanTickUpper() public {
        // Given :
    }
}
