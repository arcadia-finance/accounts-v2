/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
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
    ) public {
        // Given: Ticks are within allowed ranges.
        position = givenValidPosition(position, 1);

        // Avoid divide by 0, which is already checked in earlier in function.
        priceToken1 = bound(priceToken1, 1, type(uint256).max);
        // Function will overFlow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);
        // Cast to uint160 will overflow, not realistic.
        if (priceToken1 < 2 ** 128) priceToken0 = bound(priceToken0, 0, priceToken1 * 2 ** 128);

        uint160 sqrtPriceX96 = stakedSlipstreamAM.getSqrtPriceX96(priceToken0, priceToken1);
        (uint256 expectedAmount0, uint256 expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );

        (uint256 actualAmount0, uint256 actualAmount1) = stakedSlipstreamAM.getPrincipalAmounts(
            position.tickLower, position.tickUpper, position.liquidity, priceToken0, priceToken1
        );
        assertEq(actualAmount0, expectedAmount0);
        assertEq(actualAmount1, expectedAmount1);
    }
}
