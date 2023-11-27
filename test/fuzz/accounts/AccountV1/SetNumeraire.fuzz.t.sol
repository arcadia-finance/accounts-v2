/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setNumeraire" of contract "AccountV1".
 */
contract SetNumeraire_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

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
        accountExtension.setLocked(2);

        vm.prank(users.accountOwner);
        vm.expectRevert(AccountErrors.NoReentry.selector);
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
        vm.assume(!registryExtension.inRegistry(numeraire_));

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.NumeraireNotFound.selector);
        accountExtension.setNumeraire(numeraire_);
        vm.stopPrank();
    }

    function testFuzz_Success_setNumeraire() public {
        vm.startPrank(users.accountOwner);
        vm.expectEmit(true, true, true, true);
        emit NumeraireSet(address(mockERC20.token1));
        accountExtension.setNumeraire(address(mockERC20.token1));
        vm.stopPrank();

        assertEq(accountExtension.numeraire(), address(mockERC20.token1));
    }
}
