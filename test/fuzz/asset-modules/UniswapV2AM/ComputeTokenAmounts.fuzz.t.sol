/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "computeTokenAmounts" of contract "UniswapV2AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract ComputeTokenAmounts_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_computeTokenAmounts_FeeOff(
        uint112 reserve0,
        uint112 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount
    ) public view {
        // division by 0
        totalSupply = bound(totalSupply, 1, type(uint256).max);
        reserve0 = uint112(bound(reserve0, 1, type(uint112).max));
        reserve1 = uint112(bound(reserve1, 1, type(uint112).max));
        // single user can never hold more than totalSupply, and no overflow on unrealistic big liquidityAmount
        uint256 maxLiquidityAmount = type(uint256).max / reserve0;
        if (type(uint256).max / reserve1 < maxLiquidityAmount) maxLiquidityAmount = type(uint256).max / reserve1;
        if (totalSupply < maxLiquidityAmount) maxLiquidityAmount = totalSupply;
        liquidityAmount = bound(liquidityAmount, 0, maxLiquidityAmount);

        uint256 token0AmountExpected = liquidityAmount * reserve0 / totalSupply;
        uint256 token1AmountExpected = liquidityAmount * reserve1 / totalSupply;

        (uint256 token0AmountActual, uint256 token1AmountActual) =
            uniswapV2AM.computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, 0);

        assertEq(token0AmountActual, token0AmountExpected);
        assertEq(token1AmountActual, token1AmountExpected);
    }

    function testFuzz_Success_computeTokenAmounts_FeeOn(
        uint112 reserve0Last,
        uint112 reserve1Last,
        uint112 reserve0,
        uint144 totalSupply, //might overflow for totalsupply bigger than 2¨^144
        uint144 liquidityAmount
    ) public {
        // division by 0
        totalSupply = uint144(bound(totalSupply, 10e6 + 1, type(uint144).max));
        reserve0Last = uint112(bound(reserve0Last, 10e6 + 1, type(uint112).max - 1));
        reserve1Last = uint112(bound(reserve1Last, 10e6 + 1, type(uint112).max));
        // single user can never hold more than totalSupply
        liquidityAmount = uint144(bound(liquidityAmount, 0, totalSupply));
        // Uniswap accrues fees
        // reserve1 is max uint112 (uniswap)
        uint256 maxReserve0 = uint256(type(uint112).max) * reserve0Last / reserve1Last;
        if (maxReserve0 > type(uint112).max) maxReserve0 = type(uint112).max;
        vm.assume(maxReserve0 > reserve0Last);
        reserve0 = uint112(bound(reserve0, reserve0Last + 1, maxReserve0));
        uint112 reserve1 = uint112(uint256(reserve0) * reserve1Last / reserve0Last); // pool is still balanced and fees accrued

        // Given: Fees are enabled
        vm.prank(HAYDEN_ADAMS);
        uniswapV2Factory.setFeeTo(address(1));
        uniswapV2AM.syncFee();

        uint256 token0Fee = (reserve0 - reserve0Last) / 6; // a sixth of all fees go to the Uniswap treasury when fees are enabled
        uint256 token1Fee = (reserve1 - reserve1Last) / 6;

        uint256 token0AmountExpected = uint256(liquidityAmount) * (reserve0 - token0Fee) / totalSupply; // substract the fees to the treasury from the reserves
        uint256 token1AmountExpected = uint256(liquidityAmount) * (reserve1 - token1Fee) / totalSupply;

        uint256 kLast = uint256(reserve0Last) * reserve1Last;
        (uint256 token0AmountActual, uint256 token1AmountActual) =
            uniswapV2AM.computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, kLast);

        assertInRange(token0AmountActual, token0AmountExpected, 3); // Due numerical errors (integer divisions, and sqrt function) result will not be exactly equal
        assertInRange(token1AmountActual, token1AmountExpected, 3);
    }
}
