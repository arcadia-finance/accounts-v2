/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "closeMarginAccount" of contract "AccountV1".
 */
contract CloseMarginAccount_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_closeMarginAccount_NonOwner(address nonOwner) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        proxyAccount.closeMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Revert_closeMarginAccount_NotDuringAuction() public {
        // Set "inAuction" to true.
        accountExtension.setInAuction();

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.closeMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Revert_closeMarginAccount_NonSetMarginAccount() public {
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.CreditorNotSet.selector);
        proxyAccount.closeMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Revert_closeMarginAccount_OpenPosition(uint256 debt_) public {
        vm.prank(users.accountOwner);
        proxyAccount.openMarginAccount(address(creditorStable1));

        // Mock debt.
        vm.assume(debt_ > 0);
        creditorStable1.setOpenPosition(address(proxyAccount), debt_);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(OpenPositionNonZero.selector);
        proxyAccount.closeMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Success_closeMarginAccount() public {
        vm.prank(users.accountOwner);
        proxyAccount.openMarginAccount(address(creditorStable1));

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit MarginAccountChanged(address(0), address(0));
        proxyAccount.closeMarginAccount();
        vm.stopPrank();

        assertTrue(proxyAccount.creditor() == address(0));
        assertTrue(proxyAccount.liquidator() == address(0));
    }
}
