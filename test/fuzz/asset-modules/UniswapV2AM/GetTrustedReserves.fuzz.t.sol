/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test, UniswapV2AM } from "./_UniswapV2AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getTrustedReserves" of contract "UniswapV2AM".
 */
contract GetTrustedReserves_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getTrustedReserves_ZeroReserves(uint256 trustedPriceToken0, uint256 trustedPriceToken1)
        public
    {
        vm.expectRevert(UniswapV2AM.Zero_Reserves.selector);
        uniswapV2AM.getTrustedReserves(address(pairToken1Token2), trustedPriceToken0, trustedPriceToken1);
    }

    function testFuzz_Success_getTrustedReserves(
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

        pairToken1Token2.setReserves(reserve0, reserve1);

        (bool token0ToToken1, uint256 amountIn) =
            uniswapV2AM.computeProfitMaximizingTrade(priceToken0, priceToken1, reserve0, reserve1);

        uint256 amountOut;
        uint256 expectedTrustedReserve0;
        uint256 expectedTrustedReserve1;
        if (token0ToToken1) {
            amountOut = uniswapV2AM.getAmountOut(amountIn, reserve0, reserve1);
            expectedTrustedReserve0 = reserve0 + amountIn;
            expectedTrustedReserve1 = reserve1 - amountOut;
        } else {
            amountOut = uniswapV2AM.getAmountOut(amountIn, reserve1, reserve0);
            expectedTrustedReserve0 = reserve0 - amountOut;
            expectedTrustedReserve1 = reserve1 + amountIn;
        }

        (uint256 actualTrustedReserve0, uint256 actualTrustedReserve1) =
            uniswapV2AM.getTrustedReserves(address(pairToken1Token2), priceToken0, priceToken1);
        assertEq(actualTrustedReserve0, expectedTrustedReserve0);
        assertEq(actualTrustedReserve1, expectedTrustedReserve1);
    }
}
