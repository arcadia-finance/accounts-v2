/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountErrors } from "../../../../src/libraries/Errors.sol";
import { AccountV4_Fuzz_Test } from "./_AccountV4.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "transferOwnership" of contract "AccountV4".
 */
contract TransferOwnership_AccountV3_Fuzz_Test is AccountV4_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV4_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_transferOwnership_NonFactory(address sender, address to) public {
        vm.assume(sender != address(factory));

        assertEq(users.accountOwner, accountSpot.owner());

        vm.prank(sender);
        vm.expectRevert(AccountErrors.OnlyFactory.selector);
        accountSpot.transferOwnership(to);

        assertEq(users.accountOwner, accountSpot.owner());
    }

    function testFuzz_Revert_transferOwnership_CoolDownPeriodNotPassed(
        address to,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(to != address(0));

        accountSpot.setLastActionTimestamp(lastActionTimestamp);

        timePassed = uint32(bound(timePassed, 0, accountSpot.getCoolDownPeriod()));
        vm.warp(uint256(lastActionTimestamp) + timePassed);

        vm.prank(address(factory));
        vm.expectRevert(AccountErrors.CoolDownPeriodNotPassed.selector);
        accountSpot.transferOwnership(to);
    }

    function testFuzz_Success_transferOwnership(address to, uint32 lastActionTimestamp, uint32 timePassed) public {
        vm.assume(to != address(0));

        assertEq(users.accountOwner, accountSpot.owner());

        accountSpot.setLastActionTimestamp(lastActionTimestamp);

        timePassed = uint32(bound(timePassed, accountSpot.getCoolDownPeriod() + 1, type(uint32).max));
        vm.warp(uint256(lastActionTimestamp) + timePassed);

        vm.prank(address(factory));
        accountSpot.transferOwnership(to);

        assertEq(to, accountSpot.owner());
    }
}
