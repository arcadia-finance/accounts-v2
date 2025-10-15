/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { TickMath } from "../../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "UniswapV4HooksRegistry".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetValue_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getValue_valueInUsd(TestVariables memory vars) public {
        // Given : Valid ticks
        (vars.tickLower, vars.tickUpper) = givenValidTicks(vars.tickLower, vars.tickUpper);

        // And : Deploy and sort tokens.
        vars.decimals0 = bound(vars.decimals0, 6, 18);
        vars.decimals1 = bound(vars.decimals1, 6, 18);

        vm.startPrank(users.tokenCreator);
        ERC20 token0_ = new ERC20Mock("TOKEN0", "TOK0", uint8(vars.decimals0));
        ERC20 token1_ = new ERC20Mock("TOKEN1", "TOK1", uint8(vars.decimals1));
        if (token0_ > token1_) {
            (token0_, token1_) = (token1_, token0_);
            (vars.decimals0, vars.decimals1) = (vars.decimals1, vars.decimals0);
            (vars.priceToken0, vars.priceToken1) = (vars.priceToken1, vars.priceToken0);
        }
        vm.stopPrank();

        // And : Avoid divide by 0 in next line.
        vm.assume(vars.priceToken1 > 0);
        // And : Cast to uint160 will overflow, not realistic.
        vm.assume(vars.priceToken0 / vars.priceToken1 < 2 ** 128);
        // Check that sqrtPriceX96 is within allowed Uniswap V4 ranges.
        uint160 sqrtPriceX96 = uniswapV4AM.getSqrtPriceX96(
            vars.priceToken0 * 10 ** (18 - vars.decimals0), vars.priceToken1 * 10 ** (18 - vars.decimals1)
        );

        vm.assume(sqrtPriceX96 >= MIN_SQRT_PRICE);
        vm.assume(sqrtPriceX96 <= MAX_SQRT_PRICE);

        // And : Initialize Uniswap V4 pool initiated at tickCurrent with tickSpacing = 1.
        int24 tickSpacing = 1;
        randomPoolKey =
            initializePoolV4(address(token0_), address(token1_), sqrtPriceX96, address(validHook), 500, tickSpacing);

        // And : Liquidity is within allowed ranges.
        vars.liquidity =
            uint80(bound(vars.liquidity, 1e18 + 1, poolManager.getTickSpacingToMaxLiquidityPerTick(tickSpacing)) / 10);

        // And : Liquidity position is minted.
        uint256 tokenId = mintPositionV4(
            randomPoolKey,
            vars.tickLower,
            vars.tickUpper,
            vars.liquidity,
            type(uint128).max,
            type(uint128).max,
            users.owner
        );

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        bytes32 positionKey = keccak256(
            abi.encodePacked(address(positionManagerV4), vars.tickLower, vars.tickUpper, bytes32(uint256(tokenId)))
        );
        uint128 liquidity = stateView.getPositionLiquidity(randomPoolKey.toId(), positionKey);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(vars.tickLower),
            TickMath.getSqrtPriceAtTick(vars.tickUpper),
            liquidity
        );

        // And : Overflows Uniswap libraries, not realistic.
        vm.assume(amount0 < type(uint104).max);
        vm.assume(amount1 < type(uint104).max);

        // And : Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0_), int256(uint256(vars.priceToken0)));
        addAssetToArcadia(address(token1_), int256(uint256(vars.priceToken1)));

        // Calculate the expected value
        uint256 valueToken0 = uint256(vars.priceToken0) * amount0 / 10 ** vars.decimals0;
        uint256 valueToken1 = uint256(vars.priceToken1) * amount1 / 10 ** vars.decimals1;

        // When : calling getValue()
        (uint256 actualValueInUsd,,) =
            v4HooksRegistry.getValue(address(creditorUsd), address(positionManagerV4), tokenId, 1);

        // Then : It should return the correct value
        assertEq(actualValueInUsd, valueToken0 + valueToken1);
    }

    function testFuzz_Success_getValue_RiskFactors(
        uint256 decimals0,
        uint256 decimals1,
        uint256 collFactor0,
        uint256 liqFactor0,
        uint256 collFactor1,
        uint256 liqFactor1,
        uint256 riskFactorUniV4
    ) public {
        // Given : Valid risk factors
        liqFactor0 = bound(liqFactor0, 0, AssetValuationLib.ONE_4);
        collFactor0 = bound(collFactor0, 0, liqFactor0);
        liqFactor1 = bound(liqFactor1, 0, AssetValuationLib.ONE_4);
        collFactor1 = bound(collFactor1, 0, liqFactor1);
        riskFactorUniV4 = bound(riskFactorUniV4, 0, AssetValuationLib.ONE_4);

        // Deploy and sort tokens.
        decimals0 = bound(decimals0, 6, 18);
        decimals1 = bound(decimals1, 6, 18);

        vm.startPrank(users.tokenCreator);
        ERC20 token0_ = new ERC20Mock("TOKEN0", "TOK0", uint8(decimals0));
        ERC20 token1_ = new ERC20Mock("TOKEN1", "TOK1", uint8(decimals1));
        if (token0_ > token1_) {
            (token0_, token1_) = (token1_, token0_);
            (decimals0, decimals1) = (decimals1, decimals0);
        }

        // And : Initialize Uniswap V4 pool initiated at tickCurrent with tickSpacing = 1.
        int24 tickSpacing = 1;
        randomPoolKey = initializePoolV4(
            address(token0_), address(token1_), TickMath.getSqrtPriceAtTick(0), address(validHook), 500, tickSpacing
        );

        // And : Liquidity position is minted.
        uint256 tokenId = mintPositionV4(randomPoolKey, 0, 10, 1e19, type(uint128).max, type(uint128).max, users.owner);

        // Add underlying tokens and its oracles to Arcadia.
        addAssetToArcadia(address(token0_), 1);
        addAssetToArcadia(address(token1_), 1);

        vm.startPrank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(token0_), 0, type(uint112).max, uint16(collFactor0), uint16(liqFactor0)
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(token1_), 0, type(uint112).max, uint16(collFactor1), uint16(liqFactor1)
        );
        v4HooksRegistry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(uniswapV4AM), type(uint112).max, uint16(riskFactorUniV4)
        );
        vm.stopPrank();

        // First take minimum of each risk factor.
        uint256 expectedCollFactor = collFactor0 < collFactor1 ? collFactor0 : collFactor1;
        uint256 expectedLiqFactor = liqFactor0 < liqFactor1 ? liqFactor0 : liqFactor1;

        // Next apply risk factor for uniswap V4.
        expectedCollFactor = expectedCollFactor * riskFactorUniV4 / AssetValuationLib.ONE_4;
        expectedLiqFactor = expectedLiqFactor * riskFactorUniV4 / AssetValuationLib.ONE_4;

        (, uint256 actualCollFactor, uint256 actualLiqFactor) =
            v4HooksRegistry.getValue(address(creditorUsd), address(positionManagerV4), tokenId, 1);

        assertEq(actualCollFactor, expectedCollFactor);
        assertEq(actualLiqFactor, expectedLiqFactor);
    }
}
