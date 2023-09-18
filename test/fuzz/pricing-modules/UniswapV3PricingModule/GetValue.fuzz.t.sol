/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, UniswapV3PricingModule_Fuzz_Test } from "./_UniswapV3PricingModule.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

import { ERC20Mock } from "../../.././utils/mocks/ERC20Mock.sol";
import { IUniswapV3PoolExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/pricing-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { TickMath } from "../../../../src/pricing-modules/UniswapV3/libraries/TickMath.sol";
import {
    IPricingModule, PricingModule
} from "../../../../src/pricing-modules/UniswapV3/UniswapV3WithFeesPricingModule.sol";

/**
 * @notice Fuzz tests for the "getValue" of contract "UniswapV3PricingModule".
 */
contract GetValue_UniswapV3PricingModule_Fuzz_Test is UniswapV3PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    // ToDo: getValue with fuzzed tokensOwed and pending Fees.

    function testFuzz_Success_getValue_valueInUsd(TestVariables memory vars) public {
        // Check that ticks are within allowed ranges.
        vm.assume(vars.tickLower < vars.tickUpper);
        vm.assume(isWithinAllowedRange(vars.tickLower));
        vm.assume(isWithinAllowedRange(vars.tickUpper));

        // Deploy and sort tokens.
        vars.decimals0 = bound(vars.decimals0, 6, 18);
        vars.decimals1 = bound(vars.decimals1, 6, 18);

        vm.startPrank(users.tokenCreatorAddress);
        ERC20 token0 = new ERC20Mock("TOKEN0", "TOK0", uint8(vars.decimals0));
        ERC20 token1 = new ERC20Mock("TOKEN1", "TOK1", uint8(vars.decimals1));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (vars.decimals0, vars.decimals1) = (vars.decimals1, vars.decimals0);
            (vars.priceToken0, vars.priceToken1) = (vars.priceToken1, vars.priceToken0);
        }

        // Avoid divide by 0 in next line.
        vm.assume(vars.priceToken1 > 0);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(vars.priceToken0 / vars.priceToken1 < 2 ** 128);
        // Check that sqrtPriceX96 is within allowed Uniswap V3 ranges.
        uint160 sqrtPriceX96 = uniV3PricingModule.getSqrtPriceX96(
            vars.priceToken0 * 10 ** (18 - vars.decimals0), vars.priceToken1 * 10 ** (18 - vars.decimals1)
        );

        vm.assume(sqrtPriceX96 >= 4_295_128_739);
        vm.assume(sqrtPriceX96 <= 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342);

        // Create Uniswap V3 pool initiated at tickCurrent with cardinality 300.
        IUniswapV3PoolExtension pool = createPool(token0, token1, sqrtPriceX96, 300);

        // Check that Liquidity is within allowed ranges.
        vm.assume(vars.liquidity <= pool.maxLiquidityPerTick());
        // Mint liquidity position.
        uint256 tokenId =
            addLiquidity(pool, vars.liquidity, users.liquidityProvider, vars.tickLower, vars.tickUpper, false);

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        (,,,,,,, uint128 liquidity_,,,,) = nonfungiblePositionManager.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(vars.tickLower),
            TickMath.getSqrtRatioAtTick(vars.tickUpper),
            liquidity_
        );

        // Overflows Uniswap libraries, not realistic.
        vm.assume(amount0 < type(uint104).max);
        vm.assume(amount1 < type(uint104).max);

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(vars.priceToken0)));
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(vars.priceToken1)));

        vm.startPrank(users.creatorAddress);
        uniV3PricingModule.setExposureOfAsset(address(token0), type(uint128).max);
        uniV3PricingModule.setExposureOfAsset(address(token1), type(uint128).max);
        vm.stopPrank();

        // Calculate the expected value
        uint256 valueToken0 = 1e18 * uint256(vars.priceToken0) * amount0 / 10 ** vars.decimals0;
        uint256 valueToken1 = 1e18 * uint256(vars.priceToken1) * amount1 / 10 ** vars.decimals1;

        (uint256 actualValueInUsd,,) = uniV3PricingModule.getValue(
            IPricingModule.GetValueInput({
                asset: address(nonfungiblePositionManager),
                assetId: tokenId,
                assetAmount: 1,
                baseCurrency: 0
            })
        );

        assertEq(actualValueInUsd, valueToken0 + valueToken1);
    }

    function testFuzz_Success_getValue_RiskFactors(
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

        PricingModule.RiskVarInput[] memory riskVarInputs = new PricingModule.RiskVarInput[](2);
        riskVarInputs[0] = PricingModule.RiskVarInput({
            asset: address(token0),
            baseCurrency: 0,
            collateralFactor: uint16(collFactor0),
            liquidationFactor: uint16(liqFactor0)
        });
        riskVarInputs[1] = PricingModule.RiskVarInput({
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
            IPricingModule.GetValueInput({
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
