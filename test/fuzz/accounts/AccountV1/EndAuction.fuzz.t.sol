/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";
import { AccountErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "AccountV1".
 */
contract endAuction_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_endAuction(address nonLiquidator) public {
        vm.assume(nonLiquidator != accountExtension.liquidator());

        vm.prank(nonLiquidator);
        vm.expectRevert(AccountErrors.OnlyLiquidator.selector);
        accountExtension.endAuction();
    }

    function testFuzz_Revert_AuctionBuy_Reentered() public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        vm.prank(accountExtension.liquidator());
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.endAuction();
    }

    function testFuzz_Success_endAuction() public {
        // Set "inAuction" to true;
        accountExtension.setInAuction();
        assertEq(accountExtension.inAuction(), true);

        // Calling endAuction() should set "inAuction" to false.
        vm.prank(accountExtension.liquidator());
        accountExtension.endAuction();

        assertEq(accountExtension.inAuction(), false);
    }
}
