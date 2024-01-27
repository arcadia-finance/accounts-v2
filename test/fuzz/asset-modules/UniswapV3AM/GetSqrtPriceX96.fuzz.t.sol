/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV3AM_Fuzz_Test } from "./_UniswapV3AM.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getSqrtPriceX96" of contract "UniswapV3AM".
 */
contract GetSqrtPriceX96_UniswapV3AM_Fuzz_Test is UniswapV3AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3AM_Fuzz_Test.setUp();

        deployUniswapV3AM(address(nonfungiblePositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getSqrtPriceX96_ZeroPriceToken1(uint256 priceToken0) public {
        // Test-case.
        uint256 priceToken1 = 0;

        uint256 expectedSqrtPriceX96 = TickMath.MAX_SQRT_RATIO;
        uint256 actualSqrtPriceX96 = uniV3AssetModule.getSqrtPriceX96(priceToken0, priceToken1);

        assertEq(actualSqrtPriceX96, expectedSqrtPriceX96);
    }

    function testFuzz_Success_getSqrtPriceX96_Overflow(uint256 priceToken0, uint256 priceToken1) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        priceToken1 = bound(priceToken1, 1, type(uint256).max);
        // Function will overFlow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e18);

        // Cast to uint160 overflows (test-case).
        vm.assume(priceToken0 / priceToken1 >= 2 ** 128);

        uint256 priceXd18 = priceToken0 * 1e18 / priceToken1;
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd9 * 2 ** 96 / 1e9;
        uint256 actualSqrtPriceX96 = uniV3AssetModule.getSqrtPriceX96(priceToken0, priceToken1);

        assertLt(actualSqrtPriceX96, expectedSqrtPriceX96);
    }

    function testFuzz_Success_getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        priceToken1 = bound(priceToken1, 1, type(uint256).max);
        // Function will overFlow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e18);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        uint256 priceXd18 = priceToken0 * 1e18 / priceToken1;
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd9 * 2 ** 96 / 1e9;
        uint256 actualSqrtPriceX96 = uniV3AssetModule.getSqrtPriceX96(priceToken0, priceToken1);

        assertEq(actualSqrtPriceX96, expectedSqrtPriceX96);
    }
}
