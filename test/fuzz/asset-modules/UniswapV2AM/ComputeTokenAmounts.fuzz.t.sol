/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "computeTokenAmounts" of contract "UniswapV2AM".
 */
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
    ) public {
        vm.assume(totalSupply > 0); // division by 0
        vm.assume(reserve0 > 0); // division by 0
        vm.assume(reserve1 > 0); // division by 0
        vm.assume(liquidityAmount <= totalSupply); // single user can never hold more than totalSupply
        vm.assume(liquidityAmount <= type(uint256).max / reserve0); // overflow, unrealistic big liquidityAmount
        vm.assume(liquidityAmount <= type(uint256).max / reserve1); // overflow, unrealistic big liquidityAmount

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
        vm.assume(totalSupply > 10e6); // division by 0
        vm.assume(reserve0Last > 10e6); // division by 0
        vm.assume(reserve1Last > 10e6); // division by 0
        vm.assume(liquidityAmount <= totalSupply); // single user can never hold more than totalSupply
        vm.assume(reserve0 > reserve0Last); // Uniswap accrues fees

        vm.assume(uint256(reserve0) * reserve1Last / reserve0Last <= type(uint112).max); // reserve1 is max uint112 (uniswap)
        uint112 reserve1 = uint112(uint256(reserve0) * reserve1Last / reserve0Last); // pool is still balanced and fees accrued

        // Given: Fees are enabled
        vm.prank(haydenAdams);
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
