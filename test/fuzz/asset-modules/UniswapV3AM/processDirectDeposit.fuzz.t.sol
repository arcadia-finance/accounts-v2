/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV3AM_Fuzz_Test, UniswapV3AM } from "./_UniswapV3AM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3PoolExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "UniswapV3AM".
 */
contract ProcessDirectDeposit_UniswapV3AM_Fuzz_Test is UniswapV3AM_Fuzz_Test {
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
        UniswapV3AM_Fuzz_Test.setUp();

        deployUniswapV3AM(address(nonfungiblePositionManager));

        token0 = new ERC20Mock("Token 0", "TOK0", 18);
        token1 = new ERC20Mock("Token 1", "TOK1", 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonRegistry(
        address creditor,
        address unprivilegedAddress,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1
    ) public {
        vm.assume(unprivilegedAddress != address(registryExtension));

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

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        uniV3AssetModule.processDirectDeposit(creditor, address(nonfungiblePositionManager), tokenId, 1);
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

        vm.startPrank(address(registryExtension));
        vm.expectRevert(UniswapV3AM.ZeroLiquidity.selector);
        uniV3AssetModule.processDirectDeposit(creditor, address(nonfungiblePositionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_ExposureToken0ExceedingMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 maxExposure0
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

        // Condition on which the call should revert: exposure to token0 becomes bigger than maxExposure0.
        vm.assume(amount0 > 0);
        vm.assume(amount0 + initialExposure0 >= maxExposure0);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0), initialExposure0, maxExposure0);
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1));

        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        uniV3AssetModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_ExposureToken1ExceedingMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure1,
        uint112 maxExposure1
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
        vm.assume(amount0 < type(uint112).max);

        // Condition on which the call should revert: exposure to token1 becomes bigger than maxExposure1.
        vm.assume(amount1 > 0);
        vm.assume(amount1 + initialExposure1 >= maxExposure1);

        // And: Usd value of underlying asset does not overflow.
        vm.assume(amount0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(priceToken0), 0, type(uint112).max);
        addUnderlyingTokenToArcadia(address(token1), int256(priceToken1), initialExposure1, maxExposure1);

        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        uniV3AssetModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_UsdExposureProtocolExceedsMax(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        // Check that ticks are within allowed ranges.
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));
        liquidity = uint128(bound(liquidity, 1, type(uint128).max));

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
            // vm.assume(amount0 + initialExposure0 < maxExposure0);
            // vm.assume(amount1 + initialExposure1 < maxExposure1);
            initialExposure0 = uint112(bound(initialExposure0, 0, maxExposure0 + amount0));
            initialExposure1 = uint112(bound(initialExposure1, 0, maxExposure1 + amount1));

            // And: Usd value of underlying assets does not overflow.
            vm.assume(amount0 + initialExposure0 < type(uint112).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
            vm.assume(amount1 + initialExposure1 < type(uint112).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        }

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniV3AssetModule.getValue(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, 0, usdExposureProtocol));
        }

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniV3AssetModule), maxUsdExposureProtocol, 100
        );

        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        uniV3AssetModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit_DepositAmountOne(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
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
            vm.assume(amount0 + initialExposure0 < maxExposure0);
            vm.assume(amount1 + initialExposure1 < maxExposure1);

            // And: Usd value of underlying assets does not overflow.
            vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
            vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        }

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniV3AssetModule.getValue(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniV3AssetModule), maxUsdExposureProtocol, 100
        );

        {
            // When: processDirectDeposit is called with amount 1.
            vm.prank(address(registryExtension));
            (uint256 recursiveCalls, uint256 assetType) = uniV3AssetModule.processDirectDeposit(
                address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1
            );

            // Then: Correct variables are returned.
            assertEq(recursiveCalls, 3);
            assertEq(assetType, 1);
        }

        {
            // And: Exposure of the asset is one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(nonfungiblePositionManager)));
            (uint256 lastExposureAsset,) = uniV3AssetModule.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 1);

            // And: Exposures to the underlying assets are updated.
            (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96, TickMath.getSqrtRatioAtTick(ticks[1]), TickMath.getSqrtRatioAtTick(ticks[2]), liquidity_
            );
            // Token0:
            bytes32 UnderlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
            assertEq(
                uniV3AssetModule.getExposureAssetToUnderlyingAssetsLast(
                    address(creditorUsd), assetKey, UnderlyingAssetKey
                ),
                amount0
            );
            (uint128 exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), UnderlyingAssetKey);
            assertEq(exposure, amount0 + initialExposure0);
            // Token1:
            UnderlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
            assertEq(
                uniV3AssetModule.getExposureAssetToUnderlyingAssetsLast(
                    address(creditorUsd), assetKey, UnderlyingAssetKey
                ),
                amount1
            );
            (exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), UnderlyingAssetKey);
            assertEq(exposure, amount1 + initialExposure1);
        }
    }

    function testFuzz_Success_processDirectDeposit_DepositAmountZero_BeforeDeposit(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
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
            vm.assume(amount0 + initialExposure0 < maxExposure0);
            vm.assume(amount1 + initialExposure1 < maxExposure1);

            // And: Usd value of underlying assets does not overflow.
            vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
            vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        }

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniV3AssetModule.getValue(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint112).max);
            maxUsdExposureProtocol = uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
        }

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniV3AssetModule), maxUsdExposureProtocol, 100
        );

        {
            // When: processDirectDeposit is called with amount 0.
            vm.prank(address(registryExtension));
            (uint256 recursiveCalls, uint256 assetType) = uniV3AssetModule.processDirectDeposit(
                address(creditorUsd), address(nonfungiblePositionManager), tokenId, 0
            );

            // Then: Correct variables are returned.
            assertEq(recursiveCalls, 3);
            assertEq(assetType, 1);
        }

        {
            // And: Exposure of the asset is one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(nonfungiblePositionManager)));
            (uint256 lastExposureAsset,) = uniV3AssetModule.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 0);

            // And: Exposures to the underlying assets are updated.
            // Token0:
            bytes32 UnderlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
            assertEq(
                uniV3AssetModule.getExposureAssetToUnderlyingAssetsLast(
                    address(creditorUsd), assetKey, UnderlyingAssetKey
                ),
                0
            );
            (uint128 exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), UnderlyingAssetKey);
            assertEq(exposure, initialExposure0);
            // Token1:
            UnderlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
            assertEq(
                uniV3AssetModule.getExposureAssetToUnderlyingAssetsLast(
                    address(creditorUsd), assetKey, UnderlyingAssetKey
                ),
                0
            );
            (exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), UnderlyingAssetKey);
            assertEq(exposure, initialExposure1);
        }
    }

    function testFuzz_Success_processDirectDeposit_DepositAmountZero_AfterDeposit(
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint112 maxUsdExposureProtocol,
        uint256 priceToken0,
        uint256 priceToken1,
        uint112 initialExposure0,
        uint112 initialExposure1,
        uint112 maxExposure0,
        uint112 maxExposure1
    ) public {
        vm.assume(tickLower < tickUpper);
        vm.assume(isWithinAllowedRange(tickLower));
        vm.assume(isWithinAllowedRange(tickUpper));

        // Calculate and check that tick current is within allowed ranges.
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(priceToken0, priceToken1));
        vm.assume(isWithinAllowedRange(TickMath.getTickAtSqrtRatio(sqrtPriceX96)));

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(TickMath.getTickAtSqrtRatio(sqrtPriceX96)), 300);

        // Check that Liquidity is within allowed ranges.
        liquidity = uint128(bound(liquidity, 1, pool.maxLiquidityPerTick() / 2));

        // Mint liquidity position.
        uint256 tokenId = addLiquidity(pool, liquidity, users.liquidityProvider, tickLower, tickUpper, false);

        uint256 amount0;
        uint256 amount1;
        {
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
                (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
                    sqrtPriceX96,
                    TickMath.getSqrtRatioAtTick(ticks[1]),
                    TickMath.getSqrtRatioAtTick(ticks[2]),
                    liquidity_
                );

                // Check that exposure to underlying tokens stays below maxExposures.
                vm.assume(amount0 + initialExposure0 < maxExposure0);
                vm.assume(amount1 + initialExposure1 < maxExposure1);

                // And: Usd value of underlying assets does not overflow.
                vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
                vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken1 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
            }

            // Add underlying tokens and its oracles to Arcadia.
            addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
            addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

            {
                // And: usd exposure to protocol below max usd exposure.
                (uint256 usdExposureProtocol,,) =
                    uniV3AssetModule.getValue(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
                vm.assume(usdExposureProtocol < type(uint112).max);
                maxUsdExposureProtocol =
                    uint112(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint112).max));
            }

            vm.prank(users.riskManager);
            registryExtension.setRiskParametersOfDerivedAM(
                address(creditorUsd), address(uniV3AssetModule), maxUsdExposureProtocol, 100
            );

            // Given: uniV3 position is deposited.
            vm.prank(address(registryExtension));
            uniV3AssetModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
        }

        {
            // And: liquidity of the deposited position is increased.
            increaseLiquidity(pool, tokenId, 100, 100, false);

            // When: processDirectDeposit is called with amount 0.
            vm.prank(address(registryExtension));
            uniV3AssetModule.processDirectDeposit(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 0);

            // Then: Exposure of the asset is still one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(tokenId), address(nonfungiblePositionManager)));
            (uint256 lastExposureAsset,) = uniV3AssetModule.getAssetExposureLast(address(creditorUsd), assetKey);
            assertEq(lastExposureAsset, 1);

            // And: Exposures to the underlying assets are of the old liquidity.
            // Token0:
            bytes32 UnderlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token0)));
            assertEq(
                uniV3AssetModule.getExposureAssetToUnderlyingAssetsLast(
                    address(creditorUsd), assetKey, UnderlyingAssetKey
                ),
                amount0
            );
            (uint128 exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), UnderlyingAssetKey);
            assertEq(exposure, amount0 + initialExposure0);
            // Token1:
            UnderlyingAssetKey = bytes32(abi.encodePacked(uint96(0), address(token1)));
            assertEq(
                uniV3AssetModule.getExposureAssetToUnderlyingAssetsLast(
                    address(creditorUsd), assetKey, UnderlyingAssetKey
                ),
                amount1
            );
            (exposure,,,) = erc20AssetModule.riskParams(address(creditorUsd), UnderlyingAssetKey);
            assertEq(exposure, amount1 + initialExposure1);
        }
    }
}
