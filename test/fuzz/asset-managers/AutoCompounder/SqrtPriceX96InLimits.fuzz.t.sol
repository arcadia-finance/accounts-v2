/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounder, TickMath } from "./_AutoCompounder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "sqrtPriceX96" of contract "AutoCompounder".
 */
contract SqrtPriceX96InLimits_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_sqrtPriceX96InLimits_ToleranceExceeded_MoveTickRight(TestVariables memory testVars)
        public
    {
        // Given : Valid State
        (testVars,) = givenValidBalancedState(testVars);

        // And : State is persisted
        setState(testVars, usdStablePool);

        // And : We move currentTick outside of tolerance zone
        // Each tick moves the price by +- 0,01%
        usdStablePool.setCurrentTick(usdStablePool.getCurrentTick() + (int24(uint24(TOLERANCE)) + 1));

        // And : Update sqrtPriceX96 in slot0
        uint160 sqrtPriceX96AtCurrentTick = TickMath.getSqrtRatioAtTick(usdStablePool.getCurrentTick());
        usdStablePool.setSqrtPriceX96(sqrtPriceX96AtCurrentTick);

        // When : calling  sqrtPriceX96InLimits()
        // Then : It should revert
        vm.expectRevert(AutoCompounder.PriceToleranceExceeded.selector);
        autoCompounder.sqrtPriceX96InLimits(address(token0), address(token1), POOL_FEE);
    }

    function testFuzz_Revert_sqrtPriceX96InLimits_ToleranceExceeded_MoveTickLeft(TestVariables memory testVars)
        public
    {
        // Given : Valid State
        (testVars,) = givenValidBalancedState(testVars);

        // And : State is persisted
        setState(testVars, usdStablePool);

        // And : We move currentTick outside of tolerance zone
        // Each tick moves the price by +- 0,01% = 1 BIPS
        // Due to quadratic relation between sqrtPrice and price, sqrtPrice can have larger deviation on the left than on the right
        usdStablePool.setCurrentTick(usdStablePool.getCurrentTick() - (int24(uint24(TOLERANCE)) + 1));

        // And : Update sqrtPriceX96 in slot0
        uint160 sqrtPriceX96AtCurrentTick = TickMath.getSqrtRatioAtTick(usdStablePool.getCurrentTick());
        usdStablePool.setSqrtPriceX96(sqrtPriceX96AtCurrentTick);

        // When : calling  sqrtPriceX96InLimits()
        // Then : It should revert
        vm.expectRevert(AutoCompounder.PriceToleranceExceeded.selector);
        autoCompounder.sqrtPriceX96InLimits(address(token0), address(token1), POOL_FEE);
    }

    function testFuzz_Success_sqrtPriceX96InLimits(TestVariables memory testVars, int24 newTick) public {
        // Given : Valid State
        bool token0HasLowestDecimals;
        (testVars, token0HasLowestDecimals) = givenValidBalancedState(testVars);

        // And : State is persisted
        setState(testVars, usdStablePool);

        // And : We move currentTick within tolerance zone
        // Each tick moves the price by +- 0,01% = 1 BIPS
        int24 currentTick = usdStablePool.getCurrentTick();
        // Due to quadratic relation between sqrtPrice and price, sqrtPrice can have larger deviation on the left than on the right
        newTick = int24(bound(newTick, currentTick - int24(uint24(TOLERANCE)), currentTick + int24(uint24(TOLERANCE))));
        usdStablePool.setCurrentTick(newTick);

        // And : Update sqrtPriceX96 in slot0
        uint160 sqrtPriceX96AtCurrentTick = TickMath.getSqrtRatioAtTick(usdStablePool.getCurrentTick());
        usdStablePool.setSqrtPriceX96(sqrtPriceX96AtCurrentTick);

        // When : calling  sqrtPriceX96InLimits()
        (int24 tick, uint160 sqrtPriceX96, uint256 usdPriceToken0, uint256 usdPriceToken1, address pool) =
            autoCompounder.sqrtPriceX96InLimits(address(token0), address(token1), POOL_FEE);

        // Then : It should return the correct values
        uint256 usdPriceToken0_ = token0HasLowestDecimals ? 1e30 : 1e18;
        uint256 usdPriceToken1_ = token0HasLowestDecimals ? 1e18 : 1e30;
        assertEq(tick, newTick);
        assertEq(usdPriceToken0, usdPriceToken0_);
        assertEq(usdPriceToken1, usdPriceToken1_);
        assertEq(sqrtPriceX96, sqrtPriceX96AtCurrentTick);
        assertEq(pool, address(usdStablePool));
    }
}
