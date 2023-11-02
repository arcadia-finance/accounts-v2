/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setBaseCurrency" of contract "AccountV1".
 */
contract SetBaseCurrency_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        vm.prank(users.accountOwner);
        accountExtension.closeTrustedMarginAccount();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setBaseCurrency_NonAuthorized(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.accountOwner);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("A: Only Owner");
        accountExtension.setBaseCurrency(address(mockERC20.token1));
        vm.stopPrank();
    }

    function testFuzz_Revert_setBaseCurrency_TrustedCreditorSet() public {
        vm.prank(users.accountOwner);
        accountExtension.openTrustedMarginAccount(address(creditorStable1));

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_SBC: Trusted Creditor Set");
        accountExtension.setBaseCurrency(address(mockERC20.token1));
        vm.stopPrank();

        assertEq(accountExtension.baseCurrency(), address(mockERC20.stable1));
    }

    function testFuzz_Revert_setBaseCurrency_BaseCurrencyNotFound(address baseCurrency_) public {
        vm.assume(baseCurrency_ != address(0));
        vm.assume(baseCurrency_ != address(mockERC20.token1));
        vm.assume(baseCurrency_ != address(mockERC20.stable1));

        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_SBC: baseCurrency not found");
        accountExtension.setBaseCurrency(baseCurrency_);
        vm.stopPrank();
    }

    function testFuzz_Success_setBaseCurrency() public {
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit BaseCurrencySet(address(mockERC20.token1));
        accountExtension.setBaseCurrency(address(mockERC20.token1));
        vm.stopPrank();

        assertEq(accountExtension.baseCurrency(), address(mockERC20.token1));
    }
}
