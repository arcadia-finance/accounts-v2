/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getUsedMargin" of contract "AccountV3".
 */
contract GetUsedMargin_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV3_Fuzz_Test.setUp();

        // Given: Creditor is set.
        openMarginAccount();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUsedMargin_CreditorNotSet(uint256 openDebt, uint96 minimumMargin) public {
        // Test-case: creditor is not set.
        accountExtension.setCreditor(address(0));

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), openDebt);

        assertEq(0, accountExtension.getUsedMargin());
    }

    function testFuzz_Success_getUsedMargin_CreditorIsSet(uint256 openDebt, uint96 minimumMargin) public {
        // No overflow of Used Margin.
        vm.assume(openDebt <= type(uint256).max - minimumMargin);

        // Test-case: creditor set.

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), openDebt);

        assertEq(openDebt + minimumMargin, accountExtension.getUsedMargin());
    }
}
