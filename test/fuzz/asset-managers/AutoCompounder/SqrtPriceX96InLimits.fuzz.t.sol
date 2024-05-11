/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounder, ERC20Mock, TickMath } from "./_AutoCompounder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "sqrtPriceX96" of contract "AutoCompounder".
 */
contract SqrtPriceX96InLimits_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */
    // TODO: delete
    event Log2(uint160 a, uint256 b);
    event Log1(uint256);

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_sqrtPriceX96InLimits_ToleranceExceeded(TestVariables memory testVars) public {
        // Given : Valid State
        bool token0HasLowestDecimals;
        (testVars, token0HasLowestDecimals) = givenValidBalancedState(testVars);

        // And : State is persisted
        uint256 tokenId = setState(testVars, usdStablePool);

        // And : We move currentTick outside of tolerance zone
        // Tolerance = 10% = 1000 BIPS, each tick moves the price by +- 0,01%
        usdStablePool.setCurrentTick(usdStablePool.getCurrentTick() + 1000);

        // And : Update sqrtPriceX96 in slot0
        uint160 sqrtPriceX96AtCurrentTick = TickMath.getSqrtRatioAtTick(usdStablePool.getCurrentTick());
        usdStablePool.setSqrtPriceX96(sqrtPriceX96AtCurrentTick);

        uint256 usdPriceToken0 = token0.decimals() < token1.decimals() ? 1e30 : 1e18;
        uint256 usdPriceToken1 = token0.decimals() < token1.decimals() ? 1e18 : 1e30;

        // Recalculate sqrtPriceX96 based on external prices
        uint256 sqrtPriceX96Calculated = autoCompounder.getSqrtPriceX96(usdPriceToken0, usdPriceToken1);

        // Check price deviation tolerance
        uint256 sqrtPriceRatio = sqrtPriceX96Calculated > sqrtPriceX96AtCurrentTick
            ? sqrtPriceX96Calculated * BIPS / sqrtPriceX96AtCurrentTick
            : uint256(sqrtPriceX96AtCurrentTick) * BIPS / sqrtPriceX96Calculated;

        emit Log2(sqrtPriceX96AtCurrentTick, sqrtPriceX96Calculated);
        emit Log1(sqrtPriceRatio);

        // When : calling  sqrtPriceX96InLimits()
        // Then : It should revert
        vm.expectRevert(AutoCompounder.PriceToleranceExceeded.selector);
        autoCompounder.sqrtPriceX96InLimits(address(token0), address(token1), POOL_FEE);
    }
}
