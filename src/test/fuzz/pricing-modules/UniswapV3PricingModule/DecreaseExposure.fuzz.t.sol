/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./UniswapV3PricingModule.fuzz.t.sol";

import { ERC20 } from "../../../../../lib/solmate/src/tokens/ERC20.sol";

import { ERC20Mock } from "../../../../mockups/ERC20SolmateMock.sol";
import { IUniswapV3PoolExtension } from "../../fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { LiquidityAmounts } from "../../../../pricing-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { TickMath } from "../../../../pricing-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the "decreaseExposure" of contract "UniswapV3PricingModule".
 */
contract DecreaseExposure_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    ERC20 token0;
    ERC20 token1;
    IUniswapV3PoolExtension pool;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();

        token0 = new ERC20Mock('Token 0', 'TOK0', 18);
        token1 = new ERC20Mock('Token 1', 'TOK1', 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_decreaseExposure_NonMainRegistry(address unprivilegedAddress, address asset, uint256 id)
        public
    {
        vm.assume(unprivilegedAddress != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        uniV3PricingModule.decreaseExposure(asset, id, 0);
        vm.stopPrank();
    }

    function testSuccess_decreaseExposure(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint128 initialExposure0,
        uint128 initialExposure1,
        uint128 maxExposure0,
        uint128 maxExposure1
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        vm.assume(liquidity > 0);

        // Calculate and check that tick current is within allowed ranges.
        int24 tickCurrent = calculateAndValidateRangeTickCurrent(priceToken0, priceToken1);
        vm.assume(tickCurrent <= int256(tickLower) + 16_095);
        vm.assume(tickCurrent >= int256(tickUpper) - 16_095);
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.liquidityProvider, tickLower, tickUpper, false);

        // Calculate expose to underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        uint256 amount0 = LiquidityAmounts.getAmount0ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );
        uint256 amount1 = LiquidityAmounts.getAmount1ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Avoid overflow.
        vm.assume(amount0 <= type(uint128).max - initialExposure0);
        vm.assume(amount1 <= type(uint128).max - initialExposure1);
        // Check that there is sufficient free exposure.
        vm.assume(amount0 + initialExposure0 <= maxExposure0);
        vm.assume(amount1 + initialExposure1 <= maxExposure1);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));
        // Set maxExposures
        vm.startPrank(users.creatorAddress);
        uniV3PricingModule.setExposure(address(token0), initialExposure0, maxExposure0);
        uniV3PricingModule.setExposure(address(token1), initialExposure1, maxExposure1);
        vm.stopPrank();

        // Deposit assets (necessary to update the position in the Pricing Module).
        vm.prank(address(mainRegistryExtension));
        uniV3PricingModule.increaseExposure(address(nonfungiblePositionManager), tokenId, 0);

        vm.prank(address(mainRegistryExtension));
        uniV3PricingModule.decreaseExposure(address(nonfungiblePositionManager), tokenId, 0);

        (, uint128 exposure0) = uniV3PricingModule.exposure(address(token0));
        (, uint128 exposure1) = uniV3PricingModule.exposure(address(token1));
        assertEq(exposure0, initialExposure0);
        assertEq(exposure1, initialExposure1);
    }
}
