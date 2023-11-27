/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FactoryGuardian_Fuzz_Test } from "./_FactoryGuardian.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unpause" of contract "FactoryGuardian".
 */
contract Unpause_WithoutArgs_FactoryGuardian_Fuzz_Test is FactoryGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FactoryGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_unpause(address random) public {
        vm.startPrank(random);
        vm.expectRevert(FunctionNotImplemented.selector);
        factoryGuardian.unpause();
        vm.stopPrank();
    }
}
