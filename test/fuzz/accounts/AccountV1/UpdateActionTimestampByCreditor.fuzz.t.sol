/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "updateActionTimestampByCreditor" of contract "AccountV1".
 */
contract UpdateActionTimestampByCreditor_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override(AccountV1_Fuzz_Test) {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_updateActionTimestampByCreditor_NonCreditor(address sender, address creditor)
        public
        notTestContracts(sender)
    {
        vm.assume(sender != creditor);

        vm.prank(users.accountOwner);
        accountExtension.setCreditor(creditor);

        vm.prank(sender);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        accountExtension.updateActionTimestampByCreditor();
    }

    function testFuzz_Success_updateActionTimestampByCreditor(uint32 time) public {
        // Given: Creditor is set.
        vm.prank(users.accountOwner);
        accountExtension.openMarginAccount(address(creditorToken1));

        // And: Random time.
        vm.warp(time);

        // When: Creditor calls updateActionTimestampByCreditor().
        vm.prank(address(creditorToken1));
        accountExtension.updateActionTimestampByCreditor();

        // Then: lastActionTimestamp is updated.
        assertEq(accountExtension.lastActionTimestamp(), time);
    }
}
