/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { StdStorage, stdStorage } from "../../../lib/forge-std/src/Test.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../mockups/ERC20SolmateMock.sol";
import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { UniswapV3Fixture, INonfungiblePositionManagerExtension } from "./fixtures/uniswap-v3/UniswapV3Fixture.f.sol";
import { IUniswapV3PoolExtension } from "../../test_old/interfaces/IUniswapV3PoolExtension.sol";
import {
    UniswapV3WithFeesPricingModule_UsdOnly,
    PricingModule_UsdOnly,
    IPricingModule_UsdOnly,
    TickMath,
    LiquidityAmounts,
    FixedPointMathLib
} from "../../PricingModules/UniswapV3/UniswapV3WithFeesPricingModule_UsdOnly.sol";
import { LiquidityAmountsExtension } from "../../test_old/libraries/LiquidityAmountsExtension.sol";
import { ArcadiaOracle } from "../../mockups/ArcadiaOracle.sol";
import { OracleHub_UsdOnly } from "../../OracleHub_UsdOnly.sol";

contract UniswapV3Test_Integration_Test is Base_IntegrationAndUnit_Test, UniswapV3Fixture {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct TestValues {
        uint256 decimals0;
        uint256 decimals1;
        uint256 amount0;
        uint256 amount1;
        int24 tickLower;
        int24 tickUpper;
        uint64 priceToken0;
        uint64 priceToken1;
        uint80 liquidity;
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    //constructor()

    function setUp() public virtual override(Base_IntegrationAndUnit_Test, UniswapV3Fixture) {
        Base_IntegrationAndUnit_Test.setUp();
        UniswapV3Fixture.setUp();

        vm.prank(users.creatorAddress);
        uniV3PricingModule.addAsset(address(nonfungiblePositionManager));
    }

    /*////////////////////////////////////////////////////////////////
                            HELPERS
    ////////////////////////////////////////////////////////////////*/

    function createPool(ERC20 token0, ERC20 token1, uint160 sqrtPriceX96, uint16 observationCardinality)
        public
        returns (IUniswapV3PoolExtension pool)
    {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        address poolAddress = nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(token0), address(token1), 100, sqrtPriceX96
        ); // Set initial price to lowest possible price.
        pool = IUniswapV3PoolExtension(poolAddress);
        pool.increaseObservationCardinalityNext(observationCardinality);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool,
        uint128 liquidity,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) public returns (uint256 tokenId) {
        (uint160 sqrtPrice,,,,,,) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );

        tokenId = addLiquidity(pool, amount0, amount1, liquidityProvider_, tickLower, tickUpper, revertsOnZeroLiquidity);
    }

    function addLiquidity(
        IUniswapV3PoolExtension pool,
        uint256 amount0,
        uint256 amount1,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) public returns (uint256 tokenId) {
        // Check if test should revert or be skipped when liquidity is zero.
        // This is hard to check with assumes of the fuzzed inputs due to rounding errors.
        if (!revertsOnZeroLiquidity) {
            (uint160 sqrtPrice,,,,,,) = pool.slot0();
            uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
                sqrtPrice,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
            vm.assume(liquidity > 0);
        }

        address token0 = pool.token0();
        address token1 = pool.token1();
        uint24 fee = pool.fee();

        deal(token0, liquidityProvider_, amount0);
        deal(token1, liquidityProvider_, amount1);
        vm.startPrank(liquidityProvider_);
        ERC20(token0).approve(address(nonfungiblePositionManager), type(uint256).max);
        ERC20(token1).approve(address(nonfungiblePositionManager), type(uint256).max);
        (tokenId,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: token0,
                token1: token1,
                fee: fee,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider_,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();
    }

    function isWithinAllowedRange(int24 tick) public pure returns (bool) {
        int24 MIN_TICK = -887_272;
        int24 MAX_TICK = -MIN_TICK;
        return (tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick))) <= uint256(uint24(MAX_TICK));
    }

    function addUnderlyingTokenToArcadia(address token, int256 price) internal {
        ArcadiaOracle oracle = initMockedOracle(0, "Token / USD");
        address[] memory oracleArr = new address[](1);
        oracleArr[0] = address(oracle);
        PricingModule_UsdOnly.RiskVarInput[] memory riskVars = new PricingModule_UsdOnly.RiskVarInput[](1);
        riskVars[0] = PricingModule_UsdOnly.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: 80,
            liquidationFactor: 90
        });

        vm.prank(users.defaultTransmitter);
        oracle.transmit(price);
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: 1,
                baseAsset: "Token",
                quoteAsset: "USD",
                oracle: address(oracle),
                baseAssetAddress: token,
                isActive: true
            })
        );
        erc20PricingModule.addAsset(token, oracleArr, riskVars, type(uint128).max);
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function test_deployUniswapV3() public {
        IUniswapV3PoolExtension pool =
            createPool(mockERC20.token1, mockERC20.token2, TickMath.getSqrtRatioAtTick(0), 300);

        uint256 tokenId = addLiquidity(pool, 1000, 1000, users.liquidityProvider, -60, 60, false);

        nonfungiblePositionManager.positions(tokenId);
    }

    /* ///////////////////////////////////////////////////////////////
                         PRICING LOGIC
    /////////////////////////////////////////////////////////////// */

    function testFuzz_getValue_valueInUsd(TestValues memory val) public {
        // Check that ticks are within allowed ranges.
        vm.assume(val.tickLower < val.tickUpper);
        vm.assume(isWithinAllowedRange(val.tickLower));
        vm.assume(isWithinAllowedRange(val.tickUpper));

        // Deploy and sort tokens.
        val.decimals0 = bound(val.decimals0, 6, 18);
        val.decimals1 = bound(val.decimals1, 6, 18);

        vm.startPrank(users.tokenCreatorAddress);
        ERC20 token0 = new ERC20Mock("TOKEN0", "TOK0", uint8(val.decimals0));
        ERC20 token1 = new ERC20Mock("TOKEN1", "TOK1", uint8(val.decimals1));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (val.decimals0, val.decimals1) = (val.decimals1, val.decimals0);
            (val.priceToken0, val.priceToken1) = (val.priceToken1, val.priceToken0);
        }

        // Avoid divide by 0 in next line.
        vm.assume(val.priceToken1 > 0);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(val.priceToken0 / val.priceToken1 < 2 ** 128);
        // Check that sqrtPriceX96 is within allowed Uniswap V3 ranges.
        uint160 sqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(
            val.priceToken0 * 10 ** (18 - val.decimals0), val.priceToken1 * 10 ** (18 - val.decimals1)
        );

        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        IUniswapV3PoolExtension pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(val.liquidity <= pool.maxLiquidityPerTick());
        // Mint liquidity position.
        uint256 tokenId =
            addLiquidity(pool, val.liquidity, users.liquidityProvider, val.tickLower, val.tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(val.tickLower),
            TickMath.getSqrtRatioAtTick(val.tickUpper),
            liquidity_
        );

        // Overflows Uniswap libraries, not realistic.
        vm.assume(amount0 < type(uint104).max);
        vm.assume(amount1 < type(uint104).max);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(val.priceToken0)));
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(val.priceToken1)));

        vm.startPrank(users.creatorAddress);
        uniV3PricingModule.setExposureOfAsset(address(token0), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(token1), type(uint128).max);
        vm.stopPrank();

        // Calculate the expected value
        uint256 valueToken0 = 1e18 * uint256(val.priceToken0) * amount0 / 10 ** val.decimals0;
        uint256 valueToken1 = 1e18 * uint256(val.priceToken1) * amount1 / 10 ** val.decimals1;

        (uint256 actualValueInUsd,,) = uniV3PricingModule.getValue(
            IPricingModule_UsdOnly.GetValueInput({
                asset: address(nonfungiblePositionManager),
                assetId: tokenId,
                assetAmount: 1,
                baseCurrency: 0
            })
        );

        assertEq(actualValueInUsd, valueToken0 + valueToken1);
    }

    function testFuzz_getValue_RiskFactors(
        uint256 collFactor0,
        uint256 liqFactor0,
        uint256 collFactor1,
        uint256 liqFactor1,
        uint256 decimals0,
        uint256 decimals1
    ) public {
        liqFactor0 = bound(liqFactor0, 0, 100);
        collFactor0 = bound(collFactor0, 0, liqFactor0);
        liqFactor1 = bound(liqFactor1, 0, 100);
        collFactor1 = bound(collFactor1, 0, liqFactor1);

        // Deploy and sort tokens.
        decimals0 = bound(decimals0, 6, 18);
        decimals1 = bound(decimals1, 6, 18);

        vm.startPrank(users.tokenCreatorAddress);
        ERC20 token0 = new ERC20Mock("TOKEN0", "TOK0", uint8(decimals0));
        ERC20 token1 = new ERC20Mock("TOKEN1", "TOK1", uint8(decimals1));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (decimals0, decimals1) = (decimals1, decimals0);
        }

        IUniswapV3PoolExtension pool = createPool(token0, token1, TickMath.getSqrtRatioAtTick(0), 300);
        uint256 tokenId = addLiquidity(pool, 1e5, users.liquidityProvider, 0, 10, true);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), 1);
        addUnderlyingTokenToArcadia(address(token1), 1);
        vm.startPrank(users.creatorAddress);
        uniV3PricingModule.setExposureOfAsset(address(token0), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(token1), type(uint128).max);
        vm.stopPrank();

        PricingModule_UsdOnly.RiskVarInput[] memory riskVarInputs = new PricingModule_UsdOnly.RiskVarInput[](2);
        riskVarInputs[0] = PricingModule_UsdOnly.RiskVarInput({
            asset: address(token0),
            baseCurrency: 0,
            collateralFactor: uint16(collFactor0),
            liquidationFactor: uint16(liqFactor0)
        });
        riskVarInputs[1] = PricingModule_UsdOnly.RiskVarInput({
            asset: address(token1),
            baseCurrency: 0,
            collateralFactor: uint16(collFactor1),
            liquidationFactor: uint16(liqFactor1)
        });
        vm.prank(users.creatorAddress);
        erc20PricingModule.setBatchRiskVariables(riskVarInputs);

        uint256 expectedCollFactor = collFactor0 < collFactor1 ? collFactor0 : collFactor1;
        uint256 expectedLiqFactor = liqFactor0 < liqFactor1 ? liqFactor0 : liqFactor1;

        (, uint256 actualCollFactor, uint256 actualLiqFactor) = uniV3PricingModule.getValue(
            IPricingModule_UsdOnly.GetValueInput({
                asset: address(nonfungiblePositionManager),
                assetId: tokenId,
                assetAmount: 1,
                baseCurrency: 0
            })
        );

        assertEq(actualCollFactor, expectedCollFactor);
        assertEq(actualLiqFactor, expectedLiqFactor);
    }
}
