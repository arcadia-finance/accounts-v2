/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountsGuard_Fuzz_Test } from "./_AccountsGuard.fuzz.t.sol";
import { AccountsGuard } from "../../../../../src/accounts/helpers/AccountsGuard.sol";

/**
 * @notice Fuzz tests for the function "changeGuardian" of contract "AccountsGuard".
 */
contract ChangeGuardian_AccountsGuard_Fuzz_Test is AccountsGuard_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountsGuard_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_changeGuardian_onlyOwner(address caller, address newGuardian) public {
        // Given: Caller is not the owner.
        vm.assume(caller != users.owner);

        // When: changeGuardian is called by a non-owner.
        // Then: It should revert.
        vm.startPrank(caller);
        vm.expectRevert("UNAUTHORIZED");
        accountsGuard.changeGuardian(newGuardian);
        vm.stopPrank();
    }

    function testFuzz_Success_changeGuardian(address newGuardian) public {
        // When: changeGuardian is called by the owner.
        // Then: Correct event is emitted.
        vm.startPrank(users.owner);
        vm.expectEmit(address(accountsGuard));
        emit AccountsGuard.GuardianChanged(users.owner, newGuardian);
        accountsGuard.changeGuardian(newGuardian);
        vm.stopPrank();

        // And: newGuardian is set.
        assertEq(accountsGuard.guardian(), newGuardian);
    }
}
