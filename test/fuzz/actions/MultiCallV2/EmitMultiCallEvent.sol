/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { MultiCallV2_Fuzz_Test } from "./_MultiCallV2.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "checkAmountOut" of contract "MultiCall".
 */
contract EmitMultiCallEvent_MultiCall_Fuzz_Test is MultiCallV2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              EVENTS
    /////////////////////////////////////////////////////////////// */

    event MultiCallExecuted(address account, uint16 actionType);

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MultiCallV2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_emitMultiCallEvent(address account, uint16 actionType) public {
        vm.expectEmit(true, true, true, true);
        emit MultiCallExecuted(account, actionType);
        action.emitMultiCallEvent(account, actionType);
    }
}
