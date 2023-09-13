/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV2PricingModule_Fuzz_Test } from "./UniswapV2PricingModule.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../../lib/forge-std/src/Test.sol";

/**
 * @notice Fuzz tests for the "getTrustedTokenAmounts" of contract "UniswapV2PricingModule".
 */
contract GetTrustedTokenAmounts_UniswapV2PricingModule_Fuzz_Test is UniswapV2PricingModule_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_getTrustedTokenAmounts_UnsufficientLiquidity(uint256 priceToken0, uint256 priceToken1) public {
        vm.expectRevert("UV2_GTTA: LIQUIDITY_AMOUNT");
        uniswapV2PricingModule.getTrustedTokenAmounts(address(pairToken1Token2), priceToken0, priceToken1, 0);
    }

    function testSuccess_getTrustedTokenAmounts(
        uint112 reserve0,
        uint112 reserve1,
        uint256 totalSupply,
        uint256 liquidityAmount
    ) public {
        // Only test for balanced pool, other tests guarantee that _getTrustedReserves brings unbalanced pool into balance
        vm.assume(liquidityAmount > 0); // division by 0
        vm.assume(reserve0 > 0); // division by 0
        vm.assume(reserve1 > 0); // division by 0
        vm.assume(liquidityAmount <= totalSupply); // single user can never hold more than totalSupply
        vm.assume(liquidityAmount <= type(uint256).max / reserve0); // overflow, unrealistic big liquidityAmount
        vm.assume(liquidityAmount <= type(uint256).max / reserve1); // overflow, unrealistic big liquidityAmount

        // Given: The reserves in the pool are reserve0 and reserve1
        pairToken1Token2.setReserves(reserve0, reserve1);
        // And: The liquidity in the pool is totalSupply
        stdstore.target(address(pairToken1Token2)).sig(pairToken1Token2.totalSupply.selector).checked_write(totalSupply);
        // And: The pool is balanced
        uint256 trustedPriceToken0 = reserve1;
        uint256 trustedPriceToken1 = reserve0;

        uint256 token0AmountExpected = liquidityAmount * reserve0 / totalSupply;
        uint256 token1AmountExpected = liquidityAmount * reserve1 / totalSupply;

        (uint256 token0AmountActual, uint256 token1AmountActual) = uniswapV2PricingModule.getTrustedTokenAmounts(
            address(pairToken1Token2), trustedPriceToken0, trustedPriceToken1, liquidityAmount
        );

        assertEq(token0AmountActual, token0AmountExpected);
        assertEq(token1AmountActual, token1AmountExpected);
    }
}
