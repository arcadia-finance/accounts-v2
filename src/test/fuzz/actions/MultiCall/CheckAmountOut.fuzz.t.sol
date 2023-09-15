/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MultiCall_Fuzz_Test } from "./_MultiCall.fuzz.t.sol";

import "../../../../actions/utils/ActionData.sol";

/**
 * @notice Fuzz tests for the "checkAmountOut" of contract "MultiCall".
 */
contract CheckAmountOut_MultiCall_Fuzz_Test is MultiCall_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MultiCall_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_checkAmountOut(uint256 amount) public {
        vm.assume(amount > 0);

        vm.expectRevert("CS: amountOut too low");
        action.checkAmountOut(address(mockERC20.token1), amount);
    }

    function testSuccess_checkAmountOut(uint256 amount, uint256 balance) public {
        vm.assume(balance >= amount);

        mockERC20.token1.mint(address(action), balance);

        action.checkAmountOut(address(mockERC20.token1), amount);
    }
}
