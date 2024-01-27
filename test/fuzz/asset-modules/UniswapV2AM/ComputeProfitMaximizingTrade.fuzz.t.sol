/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "computeProfitMaximizingTrade" of contract "UniswapV2AM".
 */
contract ComputeProfitMaximizingTrade_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_computeProfitMaximizingTrade_token0ToToken1Overflows(
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 reserve0,
        uint112 reserve1
    ) public {
        vm.assume(reserve0 > 10e6); //Minimum liquidity
        vm.assume(reserve1 > 10e6); //Minimum liquidity
        vm.assume(priceToken0 > 10e6); //Realistic prices
        vm.assume(priceToken1 > 10e6); //Realistic prices

        vm.assume(priceToken0 > type(uint256).max / reserve0);

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        uniswapV2AM.computeProfitMaximizingTrade(priceToken0, priceToken1, reserve0, reserve1);
    }

    function testFuzz_Revert_computeProfitMaximizingTrade_leftSideOverflows(
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 reserve0,
        uint112 reserve1
    ) public {
        vm.assume(reserve0 > 10e6); //Minimum liquidity
        vm.assume(reserve1 > 10e6); //Minimum liquidity
        vm.assume(priceToken0 > 10e6); //Realistic prices
        vm.assume(priceToken1 > 10e6); //Realistic prices
        vm.assume(priceToken0 <= type(uint256).max / reserve0); //Overflow, only with unrealistic big numbers
        vm.assume(priceToken1 <= type(uint256).max / 997); //Overflow, only with unrealistic big priceToken1

        bool token0ToToken1 = reserve0 * priceToken0 / reserve1 < priceToken1;
        uint256 invariant = uint256(reserve0) * reserve1 * 1000;
        uint256 prod;
        uint256 denominator;
        if (token0ToToken1) {
            prod = priceToken1;
            denominator = priceToken0 * 997;
        } else {
            prod = priceToken0;
            denominator = priceToken1 * 997;
        }
        vm.assume(invariant / denominator > type(uint256).max / prod);

        uint256 prod0; // Least significant 256 bits of the product
        uint256 prod1; // Most significant 256 bits of the product
        assembly {
            let mm := mulmod(invariant, prod, not(0))
            prod0 := mul(invariant, prod)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
        vm.expectRevert(bytes(""));
        uniswapV2AM.computeProfitMaximizingTrade(priceToken0, priceToken1, reserve0, reserve1);
    }

    function testFuzz_Success_computeProfitMaximizingTrade(
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 reserve0,
        uint112 reserve1
    ) public {
        vm.assume(reserve0 > 10e6); //Minimum liquidity
        vm.assume(reserve1 > 10e6); //Minimum liquidity
        vm.assume(priceToken0 > 10e6); //Realistic prices
        vm.assume(priceToken1 > 10e6); //Realistic prices
        vm.assume(priceToken0 <= type(uint256).max / reserve0); //Overflow, only with unrealistic big numbers
        vm.assume(priceToken1 <= type(uint256).max / 997); //Overflow, only with unrealistic big priceToken1

        uint256 invariant = uint256(reserve0) * reserve1 * 1000;
        vm.assume(invariant / priceToken1 / 997 <= type(uint256).max / priceToken0); //leftSide overflows when arb is from token 1 to 0, only with unrealistic numbers
        vm.assume(invariant / priceToken0 / 997 <= type(uint256).max / priceToken1); //leftSide overflows when arb is from token 0 to 1, only with unrealistic numbers

        (bool token0ToToken1, uint256 amountIn) =
            uniswapV2AM.computeProfitMaximizingTrade(priceToken0, priceToken1, reserve0, reserve1);
        vm.assume(amountIn > 0);

        uint112 reserveIn;
        uint112 reserveOut;
        uint256 priceTokenIn;
        uint256 priceTokenOut;
        if (token0ToToken1) {
            reserveIn = reserve0;
            reserveOut = reserve1;
            priceTokenIn = priceToken0;
            priceTokenOut = priceToken1;
        } else {
            reserveIn = reserve1;
            reserveOut = reserve0;
            priceTokenIn = priceToken1;
            priceTokenOut = priceToken0;
        }

        uint256 maxProfit = profitArbitrage(priceTokenIn, priceTokenOut, amountIn, reserveIn, reserveOut);

        //Due to numerical rounding actual maximum might be deviating bit from calculated max, but must be in a range of 1%
        vm.assume(maxProfit <= type(uint256).max / 10_001); //Prevent overflow on underlying overflows, maxProfit can still be a ridiculous big number
        assertGe(
            maxProfit * 10_001 / 10_000,
            profitArbitrage(priceTokenIn, priceTokenOut, amountIn * 999 / 1000, reserveIn, reserveOut)
        );
        assertGe(
            maxProfit * 10_001 / 10_000,
            profitArbitrage(priceTokenIn, priceTokenOut, amountIn * 1001 / 1000, reserveIn, reserveOut)
        );
    }
}
