/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { PoolKey } from "../../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import { PositionInfoLibrary, PositionInfo } from "../../../../lib/v4-periphery/src/libraries/PositionInfoLibrary.sol";
import { TickMath } from "../../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getPrincipalAmounts" of contract "DefaultUniswapV4AM".
 */
contract GetPrincipalAmounts_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getPrincipalAmounts(
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        // Given : Ticks are within allowed ranges.
        tickLower = int24(bound(tickLower, MIN_TICK, MAX_TICK - 2));
        tickUpper = int24(bound(tickUpper, tickLower + 1, MAX_TICK));

        // And : Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        // Generate PositionInfo packed struct
        PoolKey memory poolKey;
        PositionInfo info = PositionInfoLibrary.initialize(poolKey, tickLower, tickUpper);

        // And : Calculate expected principal amounts for liquidity and ticks
        uint160 sqrtPriceX96 = uniswapV4AM.getSqrtPriceX96(priceToken0, priceToken1);
        (uint256 expectedAmount0, uint256 expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity
        );

        // When : Calling getPrincipalAmounts()
        (uint256 actualAmount0, uint256 actualAmount1) =
            uniswapV4AM.getPrincipalAmounts(info, liquidity, priceToken0, priceToken1);

        // Then : It should return expected amounts
        assertEq(actualAmount0, expectedAmount0);
        assertEq(actualAmount1, expectedAmount1);
    }
}
