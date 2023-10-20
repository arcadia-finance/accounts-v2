/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MultiCall_Fuzz_Test } from "./_MultiCall.fuzz.t.sol";

import "../../../../src/actions/utils/ActionData.sol";

/**
 * @notice Fuzz tests for the "checkAmountOut" of contract "MultiCall".
 */
contract MintLP_MultiCall_Fuzz_Test is MultiCall_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MultiCall_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_MintLP(uint256 amount) public {
        vm.assume(amount > 0);

        vm.expectRevert("CS: amountOut too low");
        action.checkAmountOut(address(mockERC20.token1), amount);
    }

    function testFuzz_Success_MintLP() public { }
}
