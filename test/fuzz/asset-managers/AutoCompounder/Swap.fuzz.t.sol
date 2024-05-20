/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounder, ERC20Mock } from "./_AutoCompounder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "Swap" of contract "AutoCompounder".
 */
contract Swap_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    // TODO: delete below
    event Log(uint256);

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_success_swap_ToleranceExceeded_Right(TestVariables memory testVars) public {
        // Given : Valid State
        (testVars,) = givenValidBalancedState(testVars);

        // And : State is persisted
        setState(testVars, usdStablePool);

        (uint160 sqrtPriceX96,,,,,,) = usdStablePool.slot0();

        // And : Perform a swap to move the price accross max Tolerance
        uint256 amount1ToSwap = 1000 * token1.balanceOf(address(usdStablePool)) / BIPS;

        mintERC20TokenTo(address(token1), address(autoCompounder), amount1ToSwap);

        // When : Calling swap() on the autoCompounder, the swap should only succeed until tolerance
        autoCompounder.swap(address(usdStablePool), address(token1), int256(amount1ToSwap), sqrtPriceX96, false);

        vm.stopPrank();
    }
    /* 
    function testFuzz_revert_swap_ToleranceExceeded_Left(TestVariables memory testVars) public {
        // Given : Valid State
        (testVars,) = givenValidBalancedState(testVars);

        // And : totalFee0 is greater than totalFee1
        // And : currentTick unchanged (50/50)
        // Case for targetToken0Value < totalFee0Value
        vm.assume(testVars.feeAmount0 > testVars.feeAmount1);

        // And : State is persisted
        setState(testVars, usdStablePool);
    }

    function testFuzz_success_swap(TestVariables memory testVars) public {
        // Given : Valid State
        (testVars,) = givenValidBalancedState(testVars);

        // And : totalFee1 is greater than totalFee0
        // And : currentTick unchanged (50/50)
        // Case for targetToken0Value <= totalFee0Value
        vm.assume(testVars.feeAmount1 > uint256(testVars.feeAmount0));

        // And : State is persisted
        setState(testVars, usdStablePool);
    } */
}
