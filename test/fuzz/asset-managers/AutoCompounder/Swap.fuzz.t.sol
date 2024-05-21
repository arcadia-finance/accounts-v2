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
    function testFuzz_revert_swap_ToleranceExceeded_Right(TestVariables memory testVars) public {
        // Add liquidity for stable 1 and stable 2
        // Swap an amount that will move the price out of tolerance zone
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
