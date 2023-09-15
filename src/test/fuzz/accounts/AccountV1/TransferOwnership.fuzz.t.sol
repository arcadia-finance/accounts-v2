/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "transferOwnership" of contract "AccountV1".
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
    function testRevert_transferOwnership_NonFactory(address sender, address to) public {
        vm.assume(sender != address(factory));

        assertEq(users.accountOwner, accountExtension.owner());

        vm.startPrank(sender);
        vm.expectRevert("A: Only Factory");
        accountExtension.transferOwnership(to);
        vm.stopPrank();

        assertEq(users.accountOwner, accountExtension.owner());
    }

    function testRevert_transferOwnership_InvalidRecipient() public {
        assertEq(users.accountOwner, accountExtension.owner());

        vm.startPrank(address(factory));
        vm.expectRevert("A_TO: INVALID_RECIPIENT");
        accountExtension.transferOwnership(address(0));
        vm.stopPrank();

        assertEq(users.accountOwner, accountExtension.owner());
    }

    function testSuccess_transferOwnership(address to) public {
        vm.assume(to != address(0));

        assertEq(users.accountOwner, accountExtension.owner());

        vm.prank(address(factory));
        accountExtension.transferOwnership(to);

        assertEq(to, accountExtension.owner());
    }
}
