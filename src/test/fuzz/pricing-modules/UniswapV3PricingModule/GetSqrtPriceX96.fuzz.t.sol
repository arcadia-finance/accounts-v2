/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the "getSqrtPriceX96" of contract "UniswapV3PricingModule".
 */
contract GetSqrtPriceX96_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getSqrtPriceX96_Overflow(uint256 priceToken0, uint256 priceToken1) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        vm.assume(priceToken0 <= type(uint256).max / 1e18);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 >= 2 ** 128);

        uint256 priceXd18 = priceToken0 * 1e18 / priceToken1;
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd9 * 2 ** 96 / 1e9;
        uint256 actualSqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(priceToken0, priceToken1);

        assertLt(actualSqrtPriceX96, expectedSqrtPriceX96);
    }

    function testFuzz_Success_getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        vm.assume(priceToken0 <= type(uint256).max / 1e18);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        uint256 priceXd18 = priceToken0 * 1e18 / priceToken1;
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd9 * 2 ** 96 / 1e9;
        uint256 actualSqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(priceToken0, priceToken1);

        assertEq(actualSqrtPriceX96, expectedSqrtPriceX96);
    }
}
