/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard_Fuzz_Test } from "./_AccountsGuard.fuzz.t.sol";
import { AccountsGuard } from "../../../../../src/accounts/helpers/AccountsGuard.sol";

/**
 * @notice Fuzz tests for the function "unLock" of contract "AccountsGuard".
 */
contract UnLock_AccountsGuard_Fuzz_Test is AccountsGuard_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountsGuard_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_unLock_OnlyAccount(address account_, address caller) public {
        // Given: Caller is not the account.
        vm.assume(caller != account_);

        // And: account is set.
        accountsGuard.setAccount(account_);

        // When: unLock is called by a non-account.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountsGuard.OnlyAccount.selector);
        accountsGuard.unLock();
    }

    function testFuzz_Success_unLock(address account_) public {
        // Given: account is set.
        accountsGuard.setAccount(account_);

        // When: unLock is called by Guardian.
        vm.prank(account_);
        accountsGuard.unLock();

        // Then: The account is reset.
        assertEq(accountsGuard.getAccount(), address(0));
    }
}
