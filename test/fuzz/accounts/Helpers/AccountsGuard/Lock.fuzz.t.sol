/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountsGuard_Fuzz_Test } from "./_AccountsGuard.fuzz.t.sol";
import { AccountsGuard } from "../../../../../src/accounts/helpers/AccountsGuard.sol";

/**
 * @notice Fuzz tests for the function "lock" of contract "AccountsGuard".
 */
contract Lock_AccountsGuard_Fuzz_Test is AccountsGuard_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountsGuard_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_lock_Paused(address caller, bytes4 selector) public {
        // Given: Guard is paused.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(true);

        // When: lock is called with pauseCheck.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountsGuard.Paused.selector);
        accountsGuard.lock(true, selector);
    }

    function testFuzz_Revert_lock_Reentered(
        address caller,
        address account_,
        bool pauseCheck,
        bytes4 selector,
        uint32 blockNumber
    ) public {
        // Given: Guard is Locked.
        vm.assume(account_ != address(0));
        accountsGuard.setAccount(account_);
        accountsGuard.setBlockNumber(blockNumber);

        // And: Contract is reentered in same block.
        vm.roll(blockNumber);

        // When: lock is called.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountsGuard.Reentered.selector);
        accountsGuard.lock(pauseCheck, selector);
    }

    function testFuzz_Revert_lock_NotAnAccount(
        address caller,
        bool pauseCheck,
        bytes4 selector,
        uint32 oldBlockNumber,
        uint32 blockNumber
    ) public {
        // Given: Caller is not an Account.
        vm.assume(!factory.isAccount(caller));

        // And: Guard was locked in past.
        blockNumber = uint32(bound(blockNumber, oldBlockNumber, type(uint32).max));
        accountsGuard.setBlockNumber(oldBlockNumber);
        vm.roll(blockNumber);

        // When: lock is called.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountsGuard.OnlyAccount.selector);
        accountsGuard.lock(pauseCheck, selector);
    }

    function testFuzz_Success_lock_NoPauseCheck_NoAccountSet(
        bool pauseFlag,
        bytes4 selector,
        uint32 oldBlockNumber,
        uint32 blockNumber
    ) public {
        // Given: pause flag is set.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(pauseFlag);

        // And: Guard was locked in past.
        blockNumber = uint32(bound(blockNumber, oldBlockNumber, type(uint32).max));
        accountsGuard.setBlockNumber(oldBlockNumber);
        vm.roll(blockNumber);

        // When: lock is called.
        // Then: Correct event is emitted.
        vm.prank(address(account));
        vm.expectEmit(address(accountsGuard));
        emit AccountsGuard.Lock(address(account), selector);
        accountsGuard.lock(false, selector);

        // And: Account is Locked.
        assertEq(accountsGuard.getAccount(), address(account));
        assertEq(accountsGuard.getBlockNumber(), blockNumber);
    }

    function testFuzz_Success_lock_NoPauseCheck_AccountSet(
        bool pauseFlag,
        bytes4 selector,
        uint32 oldBlockNumber,
        uint32 blockNumber
    ) public {
        // Given: pause flag is set.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(pauseFlag);

        // And: Guard was locked in past, but not during latest block.
        accountsGuard.setAccount(address(account));
        oldBlockNumber = uint32(bound(oldBlockNumber, 0, type(uint32).max - 1));
        blockNumber = uint32(bound(blockNumber, oldBlockNumber + 1, type(uint32).max));
        accountsGuard.setBlockNumber(oldBlockNumber);
        vm.roll(blockNumber);

        // When: lock is called.
        // Then: Correct event is emitted.
        vm.prank(address(account));
        vm.expectEmit(address(accountsGuard));
        emit AccountsGuard.Lock(address(account), selector);
        accountsGuard.lock(false, selector);

        // And: Account is Locked.
        assertEq(accountsGuard.getAccount(), address(account));
        assertEq(accountsGuard.getBlockNumber(), blockNumber);
    }

    function testFuzz_Success_lock_PauseCheck_NoAccountSet(bytes4 selector, uint32 oldBlockNumber, uint32 blockNumber)
        public
    {
        // Given: Guard was locked in past.
        blockNumber = uint32(bound(blockNumber, oldBlockNumber, type(uint32).max));
        accountsGuard.setBlockNumber(oldBlockNumber);
        vm.roll(blockNumber);

        // When: lock is called.
        // Then: Correct event is emitted.
        vm.prank(address(account));
        vm.expectEmit(address(accountsGuard));
        emit AccountsGuard.Lock(address(account), selector);
        accountsGuard.lock(true, selector);

        // And: Account is Locked.
        assertEq(accountsGuard.getAccount(), address(account));
        assertEq(accountsGuard.getBlockNumber(), blockNumber);
    }

    function testFuzz_Success_lock_PauseCheck_AccountSet(bytes4 selector, uint32 oldBlockNumber, uint32 blockNumber)
        public
    {
        // Given: Guard was locked in past, but not during latest block.
        accountsGuard.setAccount(address(account));
        oldBlockNumber = uint32(bound(oldBlockNumber, 0, type(uint32).max - 1));
        blockNumber = uint32(bound(blockNumber, oldBlockNumber + 1, type(uint32).max));
        accountsGuard.setBlockNumber(oldBlockNumber);
        vm.roll(blockNumber);

        // When: lock is called.
        // Then: Correct event is emitted.
        vm.prank(address(account));
        vm.expectEmit(address(accountsGuard));
        emit AccountsGuard.Lock(address(account), selector);
        accountsGuard.lock(true, selector);

        // And: Account is Locked.
        assertEq(accountsGuard.getAccount(), address(account));
        assertEq(accountsGuard.getBlockNumber(), blockNumber);
    }
}
