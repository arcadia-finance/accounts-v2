/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { TickMath } from "../../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getSqrtPriceX96" of contract "DefaultUniswapV4AM".
 */
contract GetSqrtPriceX96_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getSqrtPriceX96_ZeroPriceToken1(uint256 priceToken0) public {
        // Given : token1 price is 0.
        uint256 priceToken1 = 0;

        // When : Calling getSqrtPriceX96().
        uint256 expectedSqrtPriceX96 = TickMath.MAX_SQRT_PRICE;
        uint256 actualSqrtPriceX96 = uniswapV4AM.getSqrtPriceX96(priceToken0, priceToken1);

        // Then : It should return MAX_SQRT_RATIO.
        assertEq(actualSqrtPriceX96, expectedSqrtPriceX96);
    }

    function testFuzz_Success_getSqrtPriceX96_Overflow(uint256 priceToken0, uint256 priceToken1) public {
        // Given : Avoid divide by 0, which is already checked in earlier in function.
        priceToken1 = bound(priceToken1, 1, type(uint256).max);
        // And : priceToken0 is max 1.158e+49, otherwise function would overflow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);

        // And : Cast to uint160 overflows (test-case).
        vm.assume(priceToken0 / priceToken1 >= 2 ** 128);

        uint256 priceXd28 = priceToken0 * 1e28 / priceToken1;
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd14 * 2 ** 96 / 1e14;
        // When : calling getSqrtPriceX96().
        uint256 actualSqrtPriceX96 = uniswapV4AM.getSqrtPriceX96(priceToken0, priceToken1);

        // Then : actualSqrtPriceX96 should be less than expected as it overflows.
        assertLt(actualSqrtPriceX96, expectedSqrtPriceX96);
    }

    function testFuzz_Success_getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public {
        // Given : Avoid divide by 0, which is already checked in earlier in function.
        priceToken1 = bound(priceToken1, 1, type(uint256).max);
        // And : priceToken0 is max 1.158e+49, otherwise function would overflow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);
        // And : Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        uint256 priceXd28 = priceToken0 * 1e28 / priceToken1;
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd14 * 2 ** 96 / 1e14;
        // When : calling getSqrtPriceX96().
        uint256 actualSqrtPriceX96 = uniswapV4AM.getSqrtPriceX96(priceToken0, priceToken1);

        // Then : It should return correct sqrtPriceX96 value.
        assertEq(actualSqrtPriceX96, expectedSqrtPriceX96);
    }
}
