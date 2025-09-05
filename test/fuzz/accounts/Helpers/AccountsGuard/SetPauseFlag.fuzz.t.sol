/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuard_Fuzz_Test } from "./_AccountsGuard.fuzz.t.sol";
import { AccountsGuard } from "../../../../../src/accounts/helpers/AccountsGuard.sol";

/**
 * @notice Fuzz tests for the function "setPauseFlag" of contract "AccountsGuard".
 */
contract SetPauseFlag_AccountsGuard_Fuzz_Test is AccountsGuard_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountsGuard_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setPauseFlag_OnlyOwner(address caller, bool flag) public {
        // Given: Caller is not the owner.
        vm.assume(caller != users.owner);

        // When: setPauseFlag is called by a non-owner.
        // Then: It should revert.
        vm.prank(caller);
        vm.expectRevert("UNAUTHORIZED");
        accountsGuard.setPauseFlag(flag);
    }

    function testFuzz_Success_setPauseFlag(bool oldFlag, bool newFlag) public {
        // Given: oldFlag is set.
        vm.prank(users.owner);
        accountsGuard.setPauseFlag(oldFlag);

        // When: setPauseFlag is called by Guardian.
        // Then: Correct event is emitted.
        vm.prank(users.owner);
        vm.expectEmit(address(accountsGuard));
        emit AccountsGuard.PauseFlagsUpdated(newFlag);
        accountsGuard.setPauseFlag(newFlag);

        // And: newFlag is set.
        assertEq(accountsGuard.paused(), newFlag);
    }
}
