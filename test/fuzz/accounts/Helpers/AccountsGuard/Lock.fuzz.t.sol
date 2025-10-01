/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard } from "../../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountsGuard_Fuzz_Test } from "./_AccountsGuard.fuzz.t.sol";
import { AccountsGuardHelper } from "../../../../utils/mocks/accounts/AccountsGuardHelper.sol";

/**
 * @notice Fuzz tests for the function "lock" of contract "AccountsGuard".
 */
contract Lock_AccountsGuard_Fuzz_Test is AccountsGuard_Fuzz_Test {
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
    function testFuzz_Revert_lock_Paused(address caller) public {
        // Given: Guard is paused.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(true);

        // When: lock is called with pauseCheck.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountsGuard.Paused.selector);
        accountsGuard.lock(true);
    }

    function testFuzz_Revert_lock_Reentered(address account_, bool pauseCheck) public {
        // Given: Guard is Locked.
        vm.assume(account_ != address(0));

        // When: lock is called.
        // Then: It should revert.
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountMock.lockWitInitialState(account_, pauseCheck);
    }

    function testFuzz_Revert_lock_NotAnAccount(address caller, bool pauseCheck) public {
        // Given: Caller is not an Account.
        vm.assume(!factory.isAccount(caller));

        // When: lock is called.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountsGuard.OnlyAccount.selector);
        accountsGuard.lock(pauseCheck);
    }

    function testFuzz_Success_lock_NoPauseCheck(bool pauseFlag) public {
        // Given: pause flag is set.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(pauseFlag);

        // When: lock is called.
        address account_ = accountMock.lockWitInitialState(address(0), false);

        // Then: Account is Locked.
        assertEq(account_, address(accountMock));
    }

    function testFuzz_Success_lock_PauseCheck() public {
        // Given: pause flag is not set.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(false);

        // When: lock is called.
        address account_ = accountMock.lockWitInitialState(address(0), true);

        // Then: Account is Locked.
        assertEq(account_, address(accountMock));
    }

    function testFuzz_Success_lock_NoUnLockCalled(bool pauseCheck) public {
        // Skip test until we can run --isolate as additional_compiler_profiles.
        // Otherwise transient storage is not cleared after calls within a test run.
        vm.skip(true);

        // Given: pause flag is not set.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(false);

        // And: Guard was locked in past, and not unlocked.
        vm.prank(address(account));
        accountsGuard.lock(pauseCheck);

        // When: lock is called.
        // Then: Transaction does not revert.
        vm.prank(address(account));
        accountsGuard.lock(pauseCheck);
    }
}
