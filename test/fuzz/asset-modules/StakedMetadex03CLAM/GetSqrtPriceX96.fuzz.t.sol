/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getSqrtPriceX96" of contract "StakedMetadex03CLAM".
 */
contract GetSqrtPriceX96_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getSqrtPriceX96_ZeroPriceToken1(uint256 priceToken0) public view {
        // Given: The price of token1 is zero.

        // When: The sqrt price is calculated.
        uint256 actualSqrtPriceX96 = stakedMetadex03CLAM.getSqrtPriceX96(priceToken0, 0);

        // Then: The maximum sqrt price is returned.
        assertEq(actualSqrtPriceX96, TickMath.MAX_SQRT_RATIO);
    }

    function testFuzz_Success_getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public view {
        // Given: The price of token1 is not zero.
        vm.assume(priceToken1 != 0);

        // And: The intermediate product of the price of token0 does not overflow.
        uint256 maxPriceToken0 = type(uint256).max / 1e28;

        // And: The relative price stays below the 2 ** 128 at which the sqrt price overflows uint160.
        if (priceToken1 <= maxPriceToken0 / 2 ** 128) maxPriceToken0 = priceToken1 * 2 ** 128 - 1;
        priceToken0 = bound(priceToken0, 0, maxPriceToken0);

        // When: The sqrt price is calculated.
        uint256 actualSqrtPriceX96 = stakedMetadex03CLAM.getSqrtPriceX96(priceToken0, priceToken1);

        // Then: The square root of the relative price is returned, with 96 binary precision.
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceToken0 * 1e28 / priceToken1);
        assertEq(actualSqrtPriceX96, sqrtPriceXd14 * 2 ** 96 / 1e14);
    }

    function testFuzz_Success_getSqrtPriceX96_Overflow(uint256 priceToken0, uint256 priceToken1) public view {
        // Given: The relative price reaches the 2 ** 128 at which the sqrt price overflows uint160.
        uint256 maxPriceToken0 = type(uint256).max / 1e28;
        priceToken1 = bound(priceToken1, 1, maxPriceToken0 / 2 ** 128);

        // And: The intermediate product of the price of token0 does not overflow.
        priceToken0 = bound(priceToken0, priceToken1 * 2 ** 128, maxPriceToken0);

        // When: The sqrt price is calculated.
        uint256 actualSqrtPriceX96 = stakedMetadex03CLAM.getSqrtPriceX96(priceToken0, priceToken1);

        // Then: The truncated sqrt price is returned.
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceToken0 * 1e28 / priceToken1);
        assertLt(actualSqrtPriceX96, sqrtPriceXd14 * 2 ** 96 / 1e14);
    }
}
