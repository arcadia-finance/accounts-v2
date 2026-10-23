/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getSqrtPriceX96" of contract "Metadex03CLAM".
 */
contract GetSqrtPriceX96_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();

        deployMetadex03CLAM(address(metadex03PositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getSqrtPriceX96_ZeroPriceToken1(uint256 priceToken0) public view {
        // Given: The usd price of token1 is zero.

        // When: The sqrtPriceX96 is calculated.
        uint256 actualSqrtPriceX96 = metadex03CLAM.getSqrtPriceX96(priceToken0, 0);

        // Then: The highest sqrtPriceX96 is returned.
        assertEq(actualSqrtPriceX96, TickMath.MAX_SQRT_RATIO);
    }

    function testFuzz_Success_getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public view {
        // Given: Trusted usd prices within the range that a sqrtPriceX96 can represent.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);
        priceToken1 = bound(priceToken1, priceToken0 / 2 ** 128 + 1, type(uint256).max);

        // When: The sqrtPriceX96 is calculated.
        uint256 actualSqrtPriceX96 = metadex03CLAM.getSqrtPriceX96(priceToken0, priceToken1);

        // Then: The square root of the relative price is returned with 96 binary precision.
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceToken0 * 1e28 / priceToken1);
        assertEq(actualSqrtPriceX96, sqrtPriceXd14 * 2 ** 96 / 1e14);
    }

    function testFuzz_Success_getSqrtPriceX96_Overflow(uint256 priceToken0, uint256 priceToken1) public view {
        // Given: Trusted usd prices with a relative price above the range a sqrtPriceX96 can represent.
        priceToken0 = bound(priceToken0, 2 ** 128, type(uint256).max / 1e28);
        priceToken1 = bound(priceToken1, 1, priceToken0 / 2 ** 128);

        // When: The sqrtPriceX96 is calculated.
        uint256 actualSqrtPriceX96 = metadex03CLAM.getSqrtPriceX96(priceToken0, priceToken1);

        // Then: The returned sqrtPriceX96 is truncated by the cast to uint160.
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceToken0 * 1e28 / priceToken1);
        assertLt(actualSqrtPriceX96, sqrtPriceXd14 * 2 ** 96 / 1e14);
    }
}
