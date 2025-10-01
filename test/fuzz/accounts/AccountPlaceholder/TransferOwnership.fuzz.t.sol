/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountPlaceholder_Fuzz_Test } from "./_AccountPlaceholder.fuzz.t.sol";
import { AccountsGuard } from "../../../../src/accounts/helpers/AccountsGuard.sol";

/**
 * @notice Fuzz tests for the function "transferOwnership" of contract "AccountPlaceholder".
 */
contract TransferOwnership_AccountPlaceholder_Fuzz_Test is AccountPlaceholder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountPlaceholder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_transferOwnership_NonFactory(address sender, address to) public {
        vm.assume(sender != address(factory));

        assertEq(users.accountOwner, account_.owner());

        vm.prank(sender);
        vm.expectRevert(AccountErrors.OnlyFactory.selector);
        account_.transferOwnership(to);

        assertEq(users.accountOwner, account_.owner());
    }

    function testFuzz_Revert_initialize_Reentered(address to) public {
        // Reentrancy guard is in locked state.
        accountsGuard.setAccount(address(1));

        vm.prank(address(factory));
        vm.expectRevert(AccountsGuard.Reentered.selector);
        account_.transferOwnership(to);
    }

    function testFuzz_Revert_transferOwnership_CoolDownPeriodNotPassed(
        address to,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(to != address(0));

        account_.setLastActionTimestamp(lastActionTimestamp);

        timePassed = uint32(bound(timePassed, 0, account_.getCoolDownPeriod()));
        vm.warp(uint256(lastActionTimestamp) + timePassed);

        vm.prank(address(factory));
        vm.expectRevert(AccountErrors.CoolDownPeriodNotPassed.selector);
        account_.transferOwnership(to);
    }

    function testFuzz_Success_transferOwnership(address to, uint32 lastActionTimestamp, uint32 timePassed) public {
        vm.assume(to != address(0));

        assertEq(users.accountOwner, account_.owner());

        account_.setLastActionTimestamp(lastActionTimestamp);

        timePassed = uint32(bound(timePassed, account_.getCoolDownPeriod() + 1, type(uint32).max));
        vm.warp(uint256(lastActionTimestamp) + timePassed);

        vm.prank(address(factory));
        account_.transferOwnership(to);

        assertEq(to, account_.owner());
    }
}
