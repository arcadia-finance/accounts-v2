/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getPrincipalAmounts" of contract "StakedSlipstreamAM".
 */
contract GetPrincipalAmounts_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getPrincipalAmounts(
        StakedSlipstreamAM.PositionState memory position,
        uint256 priceToken0,
        uint256 priceToken1
    ) public view {
        // Given: A valid position.
        position = givenValidPosition(position, 1);

        // And: The price of token1 is not zero.
        vm.assume(priceToken1 != 0);

        // And: The intermediate product of the price of token0 does not overflow.
        uint256 maxPriceToken0 = type(uint256).max / 1e28;

        // And: The relative price stays below the 2 ** 128 at which the sqrt price overflows uint160.
        if (priceToken1 <= maxPriceToken0 / 2 ** 128) maxPriceToken0 = priceToken1 * 2 ** 128 - 1;
        priceToken0 = bound(priceToken0, 0, maxPriceToken0);

        // When: getPrincipalAmounts() is called.
        (uint256 actualAmount0, uint256 actualAmount1) = stakedSlipstreamAM.getPrincipalAmounts(
            position.tickLower, position.tickUpper, position.liquidity, priceToken0, priceToken1
        );

        // Then: The token amounts of the liquidity position at the trusted price are returned.
        (uint256 expectedAmount0, uint256 expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
            stakedSlipstreamAM.getSqrtPriceX96(priceToken0, priceToken1),
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );
        assertEq(actualAmount0, expectedAmount0);
        assertEq(actualAmount1, expectedAmount1);
    }
}
