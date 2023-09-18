/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "closeTrustedMarginAccount" of contract "AccountV1".
 */
contract CloseTrustedMarginAccount_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
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
    function testFuzz_Revert_closeTrustedMarginAccount_NonOwner(address nonOwner) public {
        vm.assume(nonOwner != users.accountOwner);

        vm.startPrank(nonOwner);
        vm.expectRevert("A: Only Owner");
        proxyAccount.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Revert_closeTrustedMarginAccount_NonSetTrustedMarginAccount() public {
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_CTMA: NOT SET");
        proxyAccount.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Revert_closeTrustedMarginAccount_OpenPosition(uint256 debt_) public {
        vm.prank(users.accountOwner);
        proxyAccount.openTrustedMarginAccount(address(trustedCreditor));

        // Mock debt.
        vm.assume(debt_ > 0);
        trustedCreditor.setOpenPosition(address(proxyAccount), debt_);

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_CTMA: NON-ZERO OPEN POSITION");
        proxyAccount.closeTrustedMarginAccount();
        vm.stopPrank();
    }

    function testFuzz_Success_closeTrustedMarginAccount() public {
        vm.prank(users.accountOwner);
        proxyAccount.openTrustedMarginAccount(address(trustedCreditor));

        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit TrustedMarginAccountChanged(address(0), address(0));
        proxyAccount.closeTrustedMarginAccount();
        vm.stopPrank();

        assertTrue(!proxyAccount.isTrustedCreditorSet());
        assertTrue(proxyAccount.trustedCreditor() == address(0));
        assertTrue(proxyAccount.liquidator() == address(0));
    }
}
