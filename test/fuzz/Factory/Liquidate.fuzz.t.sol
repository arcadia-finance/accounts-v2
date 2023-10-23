/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "liquidate" of contract "Factory".
 */
contract Liquidate_Factory_Fuzz_Test is Factory_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Factory_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_liquidate_Paused(address liquidator_, address account_) public {
        vm.warp(35 days);
        vm.prank(users.guardian);
        factory.pause();

        vm.startPrank(liquidator_);
        vm.expectRevert(FunctionIsPaused.selector);
        factory.liquidate(account_);
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidate_NonAccount(address liquidator_, address nonAccount) public {
        vm.assume(nonAccount != address(proxyAccount));

        vm.startPrank(liquidator_);
        vm.expectRevert("FTRY: Not a Account");
        factory.liquidate(nonAccount);
        vm.stopPrank();
    }
}
