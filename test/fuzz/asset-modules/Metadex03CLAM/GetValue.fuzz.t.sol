/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "Metadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetValue_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();

        deployMetadex03CLAM(address(metadex03PositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    // forge-lint: disable-next-line(todo-comment)
    // ToDo: getValue with fuzzed tokensOwed and pending Fees.

    function testFuzz_Success_getValue_valueInUsd(TestVariables memory vars) public {
        // Given: Two underlying tokens, sorted the way the pool sorts them.
        vars.decimals0 = bound(vars.decimals0, 0, 18);
        vars.decimals1 = bound(vars.decimals1, 0, 18);
        vm.startPrank(users.tokenCreator);
        ERC20 token0 = new ERC20Mock("TOKEN0", "TOK0", uint8(vars.decimals0));
        ERC20 token1 = new ERC20Mock("TOKEN1", "TOK1", uint8(vars.decimals1));
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
            (vars.decimals0, vars.decimals1) = (vars.decimals1, vars.decimals0);
            (vars.priceToken0, vars.priceToken1) = (vars.priceToken1, vars.priceToken0);
        }

        // And: An initialised pool of both tokens, priced at the ratio of their trusted usd prices.
        vm.assume(vars.priceToken1 != 0);
        uint160 sqrtPriceX96 = metadex03CLAM.getSqrtPriceX96(
            vars.priceToken0 * 10 ** (18 - vars.decimals0), vars.priceToken1 * 10 ** (18 - vars.decimals1)
        );
        vm.assume(sqrtPriceX96 >= TickMath.MIN_SQRT_RATIO);
        vm.assume(sqrtPriceX96 < TickMath.MAX_SQRT_RATIO);
        ICLPoolExtension pool = createPoolMetadex03CL(address(token0), address(token1), 1, sqrtPriceX96, 300);

        // And: A valid liquidity position in that pool.
        vars.tickLower = int24(bound(vars.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        vars.tickUpper = int24(bound(vars.tickUpper, vars.tickLower + 1, TickMath.MAX_TICK));
        vars.liquidity = uint128(bound(vars.liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(
            pool, vars.liquidity, users.liquidityProvider, vars.tickLower, vars.tickUpper, false
        );

        // And: The usd value of neither underlying asset overflows.
        (,,,,,,, uint128 mintedLiquidity,,,,) = metadex03PositionManager.positions(tokenId);
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(vars.tickLower),
            TickMath.getSqrtRatioAtTick(vars.tickUpper),
            mintedLiquidity
        );
        vm.assume(
            vars.priceToken0 == 0
                || amount0 <= type(uint256).max / (uint256(vars.priceToken0) * 10 ** (18 - vars.decimals0))
        );
        vm.assume(
            vars.priceToken1 == 0
                || amount1 <= type(uint256).max / (uint256(vars.priceToken1) * 10 ** (18 - vars.decimals1))
        );

        // And: Both underlying tokens are allowed assets with a trusted usd price.
        addAssetToArcadia(address(token0), int256(uint256(vars.priceToken0)));
        addAssetToArcadia(address(token1), int256(uint256(vars.priceToken1)));

        // When: The value of the position is queried.
        (uint256 actualValueInUsd,,) =
            metadex03CLAM.getValue(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);

        // Then: The value is the usd value of both underlying token amounts.
        assertEq(
            actualValueInUsd,
            uint256(vars.priceToken0) * amount0 / 10 ** vars.decimals0 + uint256(vars.priceToken1) * amount1 / 10
                ** vars.decimals1
        );
    }

    function testFuzz_Success_getValue_RiskFactors(
        TestVariables memory vars,
        uint256 collFactor0,
        uint256 liqFactor0,
        uint256 collFactor1,
        uint256 liqFactor1,
        // forge-lint: disable-next-line(mixed-case-variable)
        uint256 riskFactorMetadex03CL
    ) public {
        // Given: Two underlying tokens, sorted the way the pool sorts them.
        vars.decimals0 = bound(vars.decimals0, 0, 18);
        vars.decimals1 = bound(vars.decimals1, 0, 18);
        vm.startPrank(users.tokenCreator);
        ERC20 token0 = new ERC20Mock("TOKEN0", "TOK0", uint8(vars.decimals0));
        ERC20 token1 = new ERC20Mock("TOKEN1", "TOK1", uint8(vars.decimals1));
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
            (vars.decimals0, vars.decimals1) = (vars.decimals1, vars.decimals0);
        }

        // And: An initialised pool of both tokens with a valid liquidity position.
        vars.tickLower = int24(bound(vars.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        vars.tickUpper = int24(bound(vars.tickUpper, vars.tickLower + 1, TickMath.MAX_TICK));
        vars.tickCurrent = int24(bound(vars.tickCurrent, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        ICLPoolExtension pool = createPoolMetadex03CL(
            address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(vars.tickCurrent), 300
        );
        vars.liquidity = uint128(bound(vars.liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(
            pool, vars.liquidity, users.liquidityProvider, vars.tickLower, vars.tickUpper, false
        );

        // And: Both underlying tokens are allowed assets with a trusted usd price of one.
        addAssetToArcadia(address(token0), 1);
        addAssetToArcadia(address(token1), 1);

        // And: No risk factor exceeds 1e4 and no collateral factor is above its liquidation factor.
        liqFactor0 = bound(liqFactor0, 0, AssetValuationLib.ONE_4);
        collFactor0 = bound(collFactor0, 0, liqFactor0);
        liqFactor1 = bound(liqFactor1, 0, AssetValuationLib.ONE_4);
        collFactor1 = bound(collFactor1, 0, liqFactor1);
        riskFactorMetadex03CL = bound(riskFactorMetadex03CL, 0, AssetValuationLib.ONE_4);
        vm.startPrank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(token0), 0, type(uint112).max, uint16(collFactor0), uint16(liqFactor0)
        );
        registry.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(token1), 0, type(uint112).max, uint16(collFactor1), uint16(liqFactor1)
        );
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(metadex03CLAM), type(uint112).max, uint16(riskFactorMetadex03CL)
        );
        vm.stopPrank();

        // When: The value of the position is queried.
        (, uint256 actualCollFactor, uint256 actualLiqFactor) =
            metadex03CLAM.getValue(address(creditorUsd), address(metadex03PositionManager), tokenId, 1);

        // Then: The lowest risk factor of both underlying assets is lowered with the protocol wide risk factor.
        uint256 expectedCollFactor = collFactor0 < collFactor1 ? collFactor0 : collFactor1;
        uint256 expectedLiqFactor = liqFactor0 < liqFactor1 ? liqFactor0 : liqFactor1;
        assertEq(actualCollFactor, expectedCollFactor * riskFactorMetadex03CL / AssetValuationLib.ONE_4);
        assertEq(actualLiqFactor, expectedLiqFactor * riskFactorMetadex03CL / AssetValuationLib.ONE_4);
    }
}
