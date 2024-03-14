/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Creditor_Fuzz_Test } from "./_Creditor.fuzz.t.sol";

import { Creditor } from "../../../src/abstracts/Creditor.sol";

/**
 * @notice Fuzz tests for the function "flashActionCallback" of contract "Creditor".
 */
contract FlashActionCallback_Creditor_Fuzz_Test is Creditor_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Creditor_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_flashActionCallback_Unauthorized(
        address account,
        address sender,
        bytes calldata callbackData
    ) public {
        vm.assume(account != sender);

        creditor.setCallbackAccount(account);

        vm.prank(sender);
        vm.expectRevert(Creditor.Unauthorized.selector);
        creditor.flashActionCallback(callbackData);
    }

    function testFuzz_Success_flashActionCallback(address account, bytes calldata callbackData) public {
        creditor.setCallbackAccount(account);

        vm.prank(account);
        creditor.flashActionCallback(callbackData);

        assertEq(creditor.getCallbackAccount(), address(0));
    }
}
