/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setApprovedCreditor" of contract "AccountV3".
 */
contract SetApprovedCreditor_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV3_Fuzz_Test.setUp();

        vm.prank(users.accountOwner);
        accountExtension.closeMarginAccount();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_setApprovedCreditor(address sender, address approvedCreditor) public {
        vm.prank(sender);
        accountExtension.setApprovedCreditor(approvedCreditor);

        assertEq(accountExtension.approvedCreditor(sender), approvedCreditor);
    }
}
