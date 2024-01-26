/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "transferOwnership" of contract "AccountV1".
 */
contract TransferOwnership_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_transferOwnership_NonFactory(address sender, address to) public {
        vm.assume(sender != address(factory));

        assertEq(users.accountOwner, accountExtension.owner());

        vm.prank(sender);
        vm.expectRevert(AccountErrors.OnlyFactory.selector);
        accountExtension.transferOwnership(to);

        assertEq(users.accountOwner, accountExtension.owner());
    }

    function testFuzz_Revert_transferOwnership_AuctionOngoing(address to) public {
        accountExtension.setInAuction();

        vm.prank(address(factory));
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.transferOwnership(to);

        assertEq(users.accountOwner, accountExtension.owner());
    }

    function testFuzz_Revert_transferOwnership_CoolDownPeriodNotPassed(
        address to,
        uint32 lastActionTimestamp,
        uint32 timePassed
    ) public {
        vm.assume(to != address(0));

        accountExtension.setLastActionTimestamp(lastActionTimestamp);

        timePassed = uint32(bound(timePassed, 0, accountExtension.getCoolDownPeriod()));
        vm.warp(uint256(lastActionTimestamp) + timePassed);

        vm.prank(address(factory));
        vm.expectRevert(AccountErrors.CoolDownPeriodNotPassed.selector);
        accountExtension.transferOwnership(to);
    }

    function testFuzz_Success_transferOwnership(address to, uint32 lastActionTimestamp, uint32 timePassed) public {
        vm.assume(to != address(0));

        assertEq(users.accountOwner, accountExtension.owner());

        accountExtension.setLastActionTimestamp(lastActionTimestamp);

        timePassed = uint32(bound(timePassed, accountExtension.getCoolDownPeriod() + 1, type(uint32).max));
        vm.warp(uint256(lastActionTimestamp) + timePassed);

        vm.prank(address(factory));
        accountExtension.transferOwnership(to);

        assertEq(to, accountExtension.owner());
    }
}
