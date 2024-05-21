/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AutoCompounder_Fuzz_Test, AutoCompounder, FixedPointMathLib, TickMath } from "./_AutoCompounder.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "GetSqrtPriceX96" of contract "AutoCompounder".
 */
contract GetSqrtPriceX96_AutoCompounder_Fuzz_Test is AutoCompounder_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AutoCompounder_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getSqrtPriceX96_ZeroPriceToken1(uint256 priceToken0) public {
        // Test-case.
        uint256 priceToken1 = 0;

        uint256 expectedSqrtPriceX96 = TickMath.MAX_SQRT_RATIO;
        uint256 actualSqrtPriceX96 = autoCompounder.getSqrtPriceX96(priceToken0, priceToken1);

        assertEq(actualSqrtPriceX96, expectedSqrtPriceX96);
    }

    function testFuzz_Success_getSqrtPriceX96_Overflow(uint256 priceToken0, uint256 priceToken1) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        priceToken1 = bound(priceToken1, 1, type(uint256).max);
        // Function will overFlow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);

        // Cast to uint160 overflows (test-case).
        vm.assume(priceToken0 / priceToken1 >= 2 ** 128);

        uint256 priceXd28 = priceToken0 * 1e28 / priceToken1;
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd14 * 2 ** 96 / 1e14;
        uint256 actualSqrtPriceX96 = autoCompounder.getSqrtPriceX96(priceToken0, priceToken1);

        assertLt(actualSqrtPriceX96, expectedSqrtPriceX96);
    }

    function testFuzz_Success_getSqrtPriceX96(uint256 priceToken0, uint256 priceToken1) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        priceToken1 = bound(priceToken1, 1, type(uint256).max);
        // Function will overFlow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        uint256 priceXd28 = priceToken0 * 1e28 / priceToken1;
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);

        uint256 expectedSqrtPriceX96 = sqrtPriceXd14 * 2 ** 96 / 1e14;
        uint256 actualSqrtPriceX96 = autoCompounder.getSqrtPriceX96(priceToken0, priceToken1);

        assertEq(actualSqrtPriceX96, expectedSqrtPriceX96);
    }
}
