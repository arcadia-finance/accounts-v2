/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard } from "../../../../../src/accounts/helpers/AccountsGuard.sol";
import { AccountsGuard_Fuzz_Test } from "./_AccountsGuard.fuzz.t.sol";
import { AccountsGuardHelper } from "../../../../utils/mocks/accounts/AccountsGuardHelper.sol";
import { LibRLP } from "../../../../../lib/solady/src/utils/LibRLP.sol";

/**
 * @notice Fuzz tests for the function "lock" of contract "AccountsGuard".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract Lock_AccountsGuard_Fuzz_Test is AccountsGuard_Fuzz_Test {
    using LibRLP for LibRLP.List;

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

    function testFuzz_Success_lock_NoUnLockCalled(bool pauseCheck, uint248 privateKey) public {
        // Given: pause flag is not set.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(false);

        // And: The Account can sign its own transactions.
        privateKey = uint248(bound(privateKey, 1, type(uint248).max));
        address account_ = vm.addr(privateKey);
        factory.setAccount(account_, 11);
        vm.deal(account_, 1 ether);

        // And: Guard was locked in past, and not unlocked.
        vm.prank(account_);
        accountsGuard.lock(pauseCheck);

        // When: lock is called from a new transaction.
        // Then: Transaction does not revert.
        vm.executeTransaction(signedLock(privateKey, account_, pauseCheck));
    }

    function signedLock(uint256 privateKey, address account_, bool pauseCheck) internal view returns (bytes memory) {
        bytes memory data = abi.encodeCall(accountsGuard.lock, (pauseCheck));
        uint256 nonce = vm.getNonce(account_);

        bytes32 digest =
            keccak256(LibRLP.encode(unsignedLock(nonce, data).p(block.chainid).p(uint256(0)).p(uint256(0))));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        return LibRLP.encode(unsignedLock(nonce, data).p(block.chainid * 2 + 35 + (v - 27)).p(uint256(r)).p(uint256(s)));
    }

    function unsignedLock(uint256 nonce, bytes memory data) internal view returns (LibRLP.List memory list) {
        list = LibRLP.p(nonce).p(uint256(1 gwei)).p(uint256(1_000_000)).p(address(accountsGuard)).p(uint256(0)).p(data);
    }
}
