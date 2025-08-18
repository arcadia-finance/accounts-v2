/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";
import { AccountV3 } from "../../../../src/accounts/AccountV3.sol";

/**
 * @notice Fuzz tests for the function "setNumeraire" of contract "AccountV3".
 */
contract SetNumeraire_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
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
    function testFuzz_Revert_setNumeraire_NonAuthorized(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.accountOwner);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        accountExtension.setNumeraire(address(mockERC20.token1));
        vm.stopPrank();
    }

    function testFuzz_Revert_setNumeraire_Reentered() public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        vm.prank(users.accountOwner);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountExtension.setNumeraire(address(mockERC20.token1));
    }

    function testFuzz_Revert_setNumeraire_CreditorSet() public {
        vm.prank(users.accountOwner);
        accountExtension.openMarginAccount(address(creditorStable1));

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.CreditorAlreadySet.selector);
        accountExtension.setNumeraire(address(mockERC20.token1));
        vm.stopPrank();

        assertEq(accountExtension.numeraire(), address(mockERC20.stable1));
    }

    function testFuzz_Revert_setNumeraire_NumeraireNotFound(address numeraire_) public {
        vm.assume(numeraire_ != address(0));
        vm.assume(!registry.inRegistry(numeraire_));

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.NumeraireNotFound.selector);
        accountExtension.setNumeraire(numeraire_);
        vm.stopPrank();
    }

    function testFuzz_Success_setNumeraire() public {
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit AccountV3.NumeraireSet(address(mockERC20.token1));
        accountExtension.setNumeraire(address(mockERC20.token1));
        vm.stopPrank();

        assertEq(accountExtension.numeraire(), address(mockERC20.token1));
    }
}
