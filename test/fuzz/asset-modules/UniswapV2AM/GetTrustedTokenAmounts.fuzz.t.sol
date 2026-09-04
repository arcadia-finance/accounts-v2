/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { UniswapV2AM } from "../../../utils/mocks/asset-modules/UniswapV2AM.sol";
import { UniswapV2AM_Fuzz_Test } from "./_UniswapV2AM.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the function "getTrustedTokenAmounts" of contract "UniswapV2AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetTrustedTokenAmounts_UniswapV2AM_Fuzz_Test is UniswapV2AM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getTrustedTokenAmounts_ZeroTotalSupply(uint256 priceToken0, uint256 priceToken1) public {
        vm.expectRevert(UniswapV2AM.Zero_Supply.selector);
        uniswapV2AM.getTrustedTokenAmounts(address(pairToken1Token2), priceToken0, priceToken1, 0);
    }

    function testFuzz_Success_getTrustedTokenAmounts(
        uint112 reserve0,
        uint112 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount
    ) public {
        // Only test for balanced pool, other tests guarantee that _getTrustedReserves brings unbalanced pool into balance
        // division by 0
        totalSupply = bound(totalSupply, 1, type(uint256).max);
        reserve0 = uint112(bound(reserve0, 1, type(uint112).max));
        reserve1 = uint112(bound(reserve1, 1, type(uint112).max));
        // single user can never hold more than totalSupply, and no overflow on unrealistic big liquidityAmount
        uint256 maxLiquidityAmount = type(uint256).max / reserve0;
        if (type(uint256).max / reserve1 < maxLiquidityAmount) maxLiquidityAmount = type(uint256).max / reserve1;
        if (totalSupply < maxLiquidityAmount) maxLiquidityAmount = totalSupply;
        liquidityAmount = bound(liquidityAmount, 1, maxLiquidityAmount);

        // Given: The reserves in the pool are reserve0 and reserve1
        pairToken1Token2.setReserves(reserve0, reserve1);
        // And: The liquidity in the pool is totalSupply
        stdstore.target(address(pairToken1Token2)).sig(pairToken1Token2.totalSupply.selector).checked_write(totalSupply);
        // And: The pool is balanced
        uint256 trustedPriceToken0 = reserve1;
        uint256 trustedPriceToken1 = reserve0;

        uint256 token0AmountExpected = liquidityAmount * reserve0 / totalSupply;
        uint256 token1AmountExpected = liquidityAmount * reserve1 / totalSupply;

        (uint256 token0AmountActual, uint256 token1AmountActual) = uniswapV2AM.getTrustedTokenAmounts(
            address(pairToken1Token2), trustedPriceToken0, trustedPriceToken1, liquidityAmount
        );

        assertEq(token0AmountActual, token0AmountExpected);
        assertEq(token1AmountActual, token1AmountExpected);
    }
}
