/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { UniswapV3AssetModule_Fuzz_Test, AssetModule } from "./_UniswapV3AssetModule.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";
import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3PoolExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "UniswapV3AssetModule".
 */
contract ProcessIndirectDeposit_UniswapV3AssetModule_Fuzz_Test is UniswapV3AssetModule_Fuzz_Test {
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
        UniswapV3AssetModule_Fuzz_Test.setUp();

        deployUniswapV3AssetModule(address(nonfungiblePositionManager));

        token0 = new ERC20Mock("Token 0", "TOK0", 18);
        token1 = new ERC20Mock("Token 1", "TOK1", 18);
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonRegistry(
        address unprivilegedAddress,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint256 exposureUpperAssetToAsset
    ) public {
        vm.assume(unprivilegedAddress != address(registryExtension));

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

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(AssetModule.Only_Registry.selector);
        uniV3AssetModule.processIndirectDeposit(
            address(creditorUsd), address(nonfungiblePositionManager), tokenId, exposureUpperAssetToAsset, 1
        );
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit(
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
            vm.assume(amount0 + initialExposure0 < maxExposure0);
            vm.assume(amount1 + initialExposure1 < maxExposure1);

            // And: Usd value of underlying assets does not overflow.
            vm.assume(amount0 + initialExposure0 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
            vm.assume(amount1 + initialExposure1 <= type(uint256).max / priceToken0 / 10 ** (18 - 0)); // divided by 10 ** (18 - DecimalsOracle).
        }

        // Add underlying tokens and its oracles to Arcadia.
        addUnderlyingTokenToArcadia(address(token0), int256(uint256(priceToken0)), initialExposure0, maxExposure0);
        addUnderlyingTokenToArcadia(address(token1), int256(uint256(priceToken1)), initialExposure1, maxExposure1);

        {
            // And: usd exposure to protocol below max usd exposure.
            (uint256 usdExposureProtocol,,) =
                uniV3AssetModule.getValue(address(creditorUsd), address(nonfungiblePositionManager), tokenId, 1);
            vm.assume(usdExposureProtocol < type(uint128).max);
            maxUsdExposureProtocol = uint128(bound(maxUsdExposureProtocol, usdExposureProtocol + 1, type(uint128).max));
        }

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfDerivedAssetModule(
            address(creditorUsd), address(uniV3AssetModule), maxUsdExposureProtocol, 100
        );

        vm.prank(address(registryExtension));
        uniV3AssetModule.processIndirectDeposit(
            address(creditorUsd), address(nonfungiblePositionManager), tokenId, 0, 1
        );
    }
}
