/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./UniswapV3PricingModule.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../../lib/solmate/src/utils/FixedPointMathLib.sol";

import { ERC20Mock } from "../../../../mockups/ERC20SolmateMock.sol";
import { TickMath } from "../../../../pricing-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the "getTrustedTickCurrent" of contract "UniswapV3PricingModule".
 */
contract GetTrustedTickCurrent_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_getTrustedTickCurrent_OverflowPriceToken0(
        uint256 decimals0,
        uint256 decimals1,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Overflow in Pricing Module
        vm.assume(priceToken1 <= type(uint256).max / 10 ** 36);
        // Makes price negative on cast to int256.
        vm.assume(priceToken0 < 2 ** 255);

        // Token decimals must be smaller then 18.
        decimals0 = bound(decimals0, 0, 18);
        decimals1 = bound(decimals1, 0, 18);

        // Condition for the overflow.
        vm.assume(priceToken0 > type(uint256).max / 10 ** (54 - decimals0));

        // Deploy tokens.
        ERC20Mock token0 = new ERC20Mock('Token 0', 'TOK0', uint8(decimals0));
        ERC20Mock token1 = new ERC20Mock('Token 1', 'TOK1', uint8(decimals1));
        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));

        vm.expectRevert(bytes(""));
        uniV3PricingModule.getTrustedTickCurrent(address(token0), address(token1));
    }

    function testRevert_getTrustedTickCurrent_OverflowPriceToken1(
        uint256 decimals0,
        uint256 decimals1,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Overflow in Pricing Module (less strict as test above!)
        vm.assume(priceToken0 <= type(uint256).max / 10 ** 36);
        // Makes price negative on cast to int256.
        vm.assume(priceToken1 < 2 ** 255);

        // Condition for the overflow.
        vm.assume(priceToken1 > type(uint256).max / 10 ** 36);

        // Token decimals must be smaller then 18.
        decimals0 = bound(decimals0, 0, 18);
        decimals1 = bound(decimals1, 0, 18);

        // Deploy tokens.
        ERC20Mock token0 = new ERC20Mock('Token 0', 'TOK0', uint8(decimals0));
        ERC20Mock token1 = new ERC20Mock('Token 1', 'TOK1', uint8(decimals1));
        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));

        vm.expectRevert(bytes(""));
        uniV3PricingModule.getTrustedTickCurrent(address(token0), address(token1));
    }

    function testRevert_getTrustedTickCurrent_sqrtPriceX96(
        uint256 decimals0,
        uint256 decimals1,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        // Token decimals must be smaller then 18.
        decimals0 = bound(decimals0, 0, 18);
        decimals1 = bound(decimals1, 0, 18);

        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        vm.assume(priceToken0 <= type(uint256).max / 10 ** (54 - decimals0)); // Overflow in _getSqrtPriceX96
        vm.assume(priceToken1 <= type(uint256).max / 10 ** 36); // Overflow in Pricing Module
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 / 10 ** decimals0 < 2 ** 128 / 10 ** decimals1);

        // Calculations.
        uint256 priceXd18 = priceToken0 * 1e18 * 10 ** decimals1 / priceToken1 / 10 ** decimals0;
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);
        uint256 sqrtPriceX96 = sqrtPriceXd9 * 2 ** 96 / 1e9;

        // Condition for the overflow.
        vm.assume(
            sqrtPriceX96 < 4_295_128_739
                || sqrtPriceX96 > 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342
        );

        // Deploy tokens.
        ERC20Mock token0 = new ERC20Mock('Token 0', 'TOK0', uint8(decimals0));
        ERC20Mock token1 = new ERC20Mock('Token 1', 'TOK1', uint8(decimals1));
        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));

        vm.expectRevert(bytes("R"));
        uniV3PricingModule.getTrustedTickCurrent(address(token0), address(token1));
    }

    function testSuccess_getTrustedTickCurrent(
        uint256 decimals0,
        uint256 decimals1,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        // Token decimals must be smaller then 18.
        decimals0 = bound(decimals0, 0, 18);
        decimals1 = bound(decimals1, 0, 18);

        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        vm.assume(priceToken0 <= type(uint256).max / 10 ** (54 - decimals0)); // Overflow in _getSqrtPriceX96
        vm.assume(priceToken1 <= type(uint256).max / 10 ** 36); // Overflow in Pricing Module
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 / 10 ** decimals0 < 2 ** 128 / 10 ** decimals1);

        // Calculations.
        uint256 priceXd18 = priceToken0 * 1e18 * 10 ** decimals1 / priceToken1 / 10 ** decimals0;
        uint256 sqrtPriceXd9 = FixedPointMathLib.sqrt(priceXd18);
        uint256 sqrtPriceX96 = sqrtPriceXd9 * 2 ** 96 / 1e9;

        // sqrtPriceX96 must be within ranges, or TickMath reverts.
        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);

        int256 expectedTickCurrent = TickMath.getTickAtSqrtRatio(uint160(sqrtPriceX96));

        // Deploy tokens.
        ERC20Mock token0 = new ERC20Mock('Token 0', 'TOK0', uint8(decimals0));
        ERC20Mock token1 = new ERC20Mock('Token 1', 'TOK1', uint8(decimals1));
        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));

        int256 actualTickCurrent = uniV3PricingModule.getTrustedTickCurrent(address(token0), address(token1));

        assertEq(actualTickCurrent, expectedTickCurrent);
    }
}
