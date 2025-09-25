/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard } from "../../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountsGuard_Fuzz_Test } from "./_AccountsGuard.fuzz.t.sol";
import { AccountsGuardHelper } from "../../../../utils/mocks/accounts/AccountsGuardHelper.sol";

/**
 * @notice Fuzz tests for the function "unLock" of contract "AccountsGuard".
 */
contract UnLock_AccountsGuard_Fuzz_Test is AccountsGuard_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    AccountsGuardHelper internal accountMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountsGuard_Fuzz_Test.setUp();

        accountMock = new AccountsGuardHelper(address(accountsGuard));
        factory.setAccount(address(accountMock), 10);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_unLock_OnlyAccount(address account_) public {
        // Given: Caller is not the account.
        vm.assume(account_ != address(accountMock));

        // When: unLock is called by a different account.
        // Then: It should revert.
        vm.expectRevert(AccountsGuard.OnlyAccount.selector);
        accountMock.unlockWitInitialState(account_);
    }

    function testFuzz_Success_unLock() public {
        // Given: account is set.
        // When: unLock is called by the account.
        address account_ = accountMock.unlockWitInitialState(address(accountMock));

        // Then: The account is reset.
        assertEq(account_, address(0));
    }
}
