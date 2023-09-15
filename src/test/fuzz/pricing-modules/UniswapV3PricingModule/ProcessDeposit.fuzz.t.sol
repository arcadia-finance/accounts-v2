/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { ERC20 } from "../../../../../lib/solmate/src/tokens/ERC20.sol";

import { ERC20Mock } from "../../../../mockups/ERC20SolmateMock.sol";
import { INonfungiblePositionManagerExtension } from
    "../../fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3PoolExtension } from "../../fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { LiquidityAmounts } from "../../../../pricing-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { TickMath } from "../../../../pricing-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the "processDeposit" of contract "UniswapV3PricingModule".
 */
contract ProcessDeposit_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
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
    function testRevert_processDeposit_NonMainRegistry(address unprivilegedAddress, address asset, uint256 id) public {
        vm.assume(unprivilegedAddress != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        uniV3PricingModule.processDeposit(address(0), asset, id, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_ZeroLiquidity() public {
        // Create Uniswap V3 pool initiated at tick 0 with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(0), 300);

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, 1000, users.liquidityProvider, -60, 60, true);

        // Decrease liquidity so that position has 0 liquidity.
        // Fetch liquidity from position instead of using input liquidity
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        vm.prank(users.liquidityProvider);
        nonfungiblePositionManager.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity_,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint160).max
            })
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PMUV3_PD: 0 liquidity");
        uniV3PricingModule.processDeposit(address(0), address(nonfungiblePositionManager), tokenId, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_BelowAcceptedRange(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        vm.assume(liquidity > 0);

        // Calculate and check that tick current is within allowed ranges.
        int24 tickCurrent = calculateAndValidateRangeTickCurrent(priceToken0, priceToken1);
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Condition on which the call should revert: tick_lower is more than 16_095 ticks below tickCurrent.
        vm.assume(tickCurrent > int256(tickLower) + 16_095);

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.liquidityProvider, tickLower, tickUpper, false);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PMUV3_PD: Tlow not in limits");
        uniV3PricingModule.processDeposit(address(0), address(nonfungiblePositionManager), tokenId, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_AboveAcceptedRange(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        vm.assume(liquidity > 0);

        // Calculate and check that tick current is within allowed ranges.
        int24 tickCurrent = calculateAndValidateRangeTickCurrent(priceToken0, priceToken1);
        vm.assume(tickCurrent <= int256(tickLower) + 16_095);
        vm.assume(isWithinAllowedRange(tickCurrent));

        // Condition on which the call should revert: tickUpper is more than 16_095 ticks above tickCurrent.
        vm.assume(tickCurrent < int256(tickUpper) - 16_095);

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.liquidityProvider, tickLower, tickUpper, false);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PMUV3_PD: Tup not in limits");
        uniV3PricingModule.processDeposit(address(0), address(nonfungiblePositionManager), tokenId, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_ExposureToken0ExceedingMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint128 initialExposure0,
        uint128 maxExposure0
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

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        uint256 amount0 = LiquidityAmounts.getAmount0ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Condition on which the call should revert: exposure to token0 becomes bigger as maxExposure0.
        vm.assume(amount0 + initialExposure0 > maxExposure0);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));
        // Set maxExposures
        vm.startPrank(users.creatorAddress);
        uniV3PricingModule.setExposure(address(token0), initialExposure0, maxExposure0);
        uniV3PricingModule.setExposure(address(token1), 0, type(uint128).max);
        vm.stopPrank();

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PMUV3_PD: Exposure0 not in limits");
        uniV3PricingModule.processDeposit(address(0), address(nonfungiblePositionManager), tokenId, 0);
        vm.stopPrank();
    }

    function testRevert_processDeposit_ExposureToken1ExceedingMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint128 initialExposure1,
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

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        uint256 amount1 = LiquidityAmounts.getAmount1ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Condition on which the call should revert: exposure to token1 becomes bigger as maxExposure1.
        vm.assume(amount1 + initialExposure1 > maxExposure1);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0));
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));
        // Set maxExposures
        vm.startPrank(users.creatorAddress);
        uniV3PricingModule.setExposure(address(token0), 0, type(uint128).max);
        uniV3PricingModule.setExposure(address(token1), initialExposure1, maxExposure1);
        vm.stopPrank();

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PMUV3_PD: Exposure1 not in limits");
        uniV3PricingModule.processDeposit(address(0), address(nonfungiblePositionManager), tokenId, 0);
        vm.stopPrank();
    }

    function testSuccess_processDeposit(
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

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        uint256 amount0 = LiquidityAmounts.getAmount0ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );
        uint256 amount1 = LiquidityAmounts.getAmount1ForLiquidity(
            TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Check that exposure to tokens stays below maxExposures.
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

        vm.prank(address(mainRegistryExtension));
        uniV3PricingModule.processDeposit(address(0), address(nonfungiblePositionManager), tokenId, 0);

        (, uint128 exposure0) = uniV3PricingModule.exposure(address(token0));
        (, uint128 exposure1) = uniV3PricingModule.exposure(address(token1));
        assertEq(exposure0, amount0 + initialExposure0);
        assertEq(exposure1, amount1 + initialExposure1);
    }
}
