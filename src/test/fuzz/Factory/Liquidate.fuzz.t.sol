/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, Factory_Fuzz_Test } from "./_Factory.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "liquidate" of contract "Factory".
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
    function testFuzz_Revert_liquidate_NonAccount(address liquidator_, address nonAccount) public {
        vm.startPrank(nonAccount);
        vm.expectRevert("FTRY: Not a Account");
        factory.liquidate(liquidator_);
        vm.stopPrank();
    }
}
