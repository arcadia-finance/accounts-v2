/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard_Fuzz_Test } from "./_AccountsGuard.fuzz.t.sol";
import { AccountsGuard } from "../../../../../src/accounts/helpers/AccountsGuard.sol";

/**
 * @notice Fuzz tests for the function "pause" of contract "AccountsGuard".
 */
contract Pause_AccountsGuard_Fuzz_Test is AccountsGuard_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountsGuard_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_pause_OnlyGuardian(address guardian, address caller) public {
        // Given: Caller is not the owner.
        vm.assume(caller != guardian);

        // And: guardian is set.
        vm.prank(users.owner);
        accountsGuard.changeGuardian(guardian);

        // When: pause is called by a non-guardian.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert(AccountsGuard.OnlyGuardian.selector);
        accountsGuard.pause();
    }

    function testFuzz_Revert_pause_Paused(address guardian) public {
        // Given: guardian is set.
        vm.prank(users.owner);
        accountsGuard.changeGuardian(guardian);

        // And: Guardian is paused.
        vm.prank(guardian);
        accountsGuard.pause();

        // When: pause is called by Guardian.
        // Then: It should revert.
        vm.prank(guardian);
        vm.expectRevert(AccountsGuard.Paused.selector);
        accountsGuard.pause();
    }

    function testFuzz_Success_pause(address guardian) public {
        // Given: guardian is set.
        vm.prank(users.owner);
        accountsGuard.changeGuardian(guardian);

        // When: pause is called by Guardian.
        // Then: Correct event is emitted.
        vm.prank(guardian);
        vm.expectEmit(address(accountsGuard));
        emit AccountsGuard.PauseFlagsUpdated(true);
        accountsGuard.pause();

        // And: Guardian is paused.
        assertTrue(accountsGuard.paused());
    }
}
