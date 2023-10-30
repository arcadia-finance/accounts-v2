/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { IPricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3PoolExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/pricing-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { TickMath } from "../../../../src/pricing-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "UniswapV3PricingModule".
 */
contract ProcessDirectDeposit_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
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

        deployUniswapV3PricingModule(address(nonfungiblePositionManager));

        token0 = new ERC20Mock('Token 0', 'TOK0', 18);
        token1 = new ERC20Mock('Token 1', 'TOK1', 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonMainRegistry(
        address creditor,
        address unprivilegedAddress,
        address asset,
        uint256 id
    ) public {
        vm.assume(unprivilegedAddress != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        uniV3PricingModule.processDirectDeposit(creditor, asset, id, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_ZeroLiquidity(address creditor) public {
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
        vm.expectRevert("PMUV3_AA: 0 liquidity");
        uniV3PricingModule.processDirectDeposit(creditor, address(nonfungiblePositionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_ExposureToken0ExceedingMax(
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
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(priceToken0, priceToken1));
        vm.assume(isWithinAllowedRange(TickMath.getTickAtSqrtRatio(sqrtPriceX96)));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        (uint256 amount0,) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // Condition on which the call should revert: exposure to token0 becomes bigger as maxExposure0.
        vm.assume(amount0 > 0);
        vm.assume(amount0 + initialExposure0 > maxExposure0);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0), initialExposure0, maxExposure0);
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APPM_PID: Exposure not in limits");
        uniV3PricingModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_ExposureToken1ExceedingMax(
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
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(priceToken0, priceToken1));
        vm.assume(isWithinAllowedRange(TickMath.getTickAtSqrtRatio(sqrtPriceX96)));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.liquidityProvider, tickLower, tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity_
        );

        // And: exposure0 does not exceed maximum.
        vm.assume(amount0 <= type(uint128).max);

        // Condition on which the call should revert: exposure to token1 becomes bigger as maxExposure1.
        vm.assume(amount1 > 0);
        vm.assume(amount1 + initialExposure1 > maxExposure1);

        // And: Usd value of underlying asset does not overflow.
        vm.assume(amount0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0), 0, type(uint128).max);
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1), initialExposure1, maxExposure1);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APPM_PID: Exposure not in limits");
        uniV3PricingModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_UsdExposureProtocolExceedsMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint128 maxUsdExposureProtocol,
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
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(priceToken0, priceToken1));
        vm.assume(isWithinAllowedRange(TickMath.getTickAtSqrtRatio(sqrtPriceX96)));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.liquidityProvider, tickLower, tickUpper, false);

        // Hacky way to avoid stack to deep.
        int24[] memory ticks = new int24[](3);
        ticks[0] = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        ticks[1] = tickLower;
        ticks[2] = tickUpper;

        {
            // Calculate amounts of underlying tokens.
            // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
            // This is because there might be some small differences due to rounding errors.
            (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96, TickMath.getSqrtRatioAtTick(ticks[1]), TickMath.getSqrtRatioAtTick(ticks[2]), liquidity_
            );

            // Check that exposure to underlying tokens stays below maxExposures.
            vm.assume(amount0 + initialExposure0 <= maxExposure0);
            vm.assume(amount1 + initialExposure1 <= maxExposure1);

            // And: Usd value of underlying assets does not overflow.
            vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
            vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        }

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) = uniV3PricingModule.getValue(
                IPricingModule.GetValueInput({
                    asset: address(nonfungiblePositionManager),
                    assetId: tokenId,
                    assetAmount: 1,
                    creditor: address(creditorUsd)
                })
            );
            vm.assume(usdExposureProtocol > 0);
            vm.assume(usdExposureProtocol <= type(uint128).max);
            maxUsdExposureProtocol = uint128(bound(maxUsdExposureProtocol, 0, usdExposureProtocol - 1));
        }

        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfDerivedPricingModule(
            address(creditorUsd), address(uniV3PricingModule), maxUsdExposureProtocol, 100
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("ADPM_PD: Exposure not in limits");
        uniV3PricingModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint128 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint128 initialExposure0,
        uint128 initialExposure1,
        uint128 maxExposure0,
        uint128 maxExposure1
    ) public {
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        vm.assume(liquidity > 0);

        // Calculate and check that tick current is within allowed ranges.
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(priceToken0, priceToken1));
        vm.assume(isWithinAllowedRange(TickMath.getTickAtSqrtRatio(sqrtPriceX96)));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(TickMath.getTickAtSqrtRatio(sqrtPriceX96)), 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(liquidity <= pool.maxLiquidityPerTick());

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.liquidityProvider, tickLower, tickUpper, false);

        // Hacky way to avoid stack to deep.
        int24[] memory ticks = new int24[](3);
        ticks[0] = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        ticks[1] = tickLower;
        ticks[2] = tickUpper;

        {
            // Calculate amounts of underlying tokens.
            // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
            // This is because there might be some small differences due to rounding errors.
            (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96, TickMath.getSqrtRatioAtTick(ticks[1]), TickMath.getSqrtRatioAtTick(ticks[2]), liquidity_
            );

            // Check that exposure to underlying tokens stays below maxExposures.
            vm.assume(amount0 + initialExposure0 <= maxExposure0);
            vm.assume(amount1 + initialExposure1 <= maxExposure1);

            // And: Usd value of underlying assets does not overflow.
            vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
            vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        }

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) = uniV3PricingModule.getValue(
                IPricingModule.GetValueInput({
                    asset: address(nonfungiblePositionManager),
                    assetId: tokenId,
                    assetAmount: 1,
                    creditor: address(creditorUsd)
                })
            );
            vm.assume(usdExposureProtocol <= type(uint128).max);
            maxUsdExposureProtocol = uint128(bound(maxUsdExposureProtocol, usdExposureProtocol, type(uint128).max));
        }

        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfDerivedPricingModule(
            address(creditorUsd), address(uniV3PricingModule), maxUsdExposureProtocol, 100
        );

        vm.prank(address(mainRegistryExtension));
        uniV3PricingModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
    }
}
