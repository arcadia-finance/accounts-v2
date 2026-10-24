/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ConcentratedLiquidityFixture } from "../concentrated-liquidity/ConcentratedLiquidityFixture.f.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { ICLPoolExtension } from "../slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { IMetadex03CLFactory } from "./interfaces/IMetadex03CLFactory.sol";
import { IMetadex03CLGauge } from "../../../../src/asset-modules/Metadex03/interfaces/IMetadex03CLGauge.sol";
import { IMetadex03CLGaugeFactory } from "./interfaces/IMetadex03CLGaugeFactory.sol";
import { IMetadex03CLPoolExtension } from "./extensions/interfaces/IMetadex03CLPoolExtension.sol";
import {
    INonfungiblePositionManagerExtension
} from "../slipstream/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { LiquidityAmountsExtension } from "../uniswap-v3/extensions/libraries/LiquidityAmountsExtension.sol";
import { Metadex03Fixture } from "./Metadex03Fixture.f.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";
import { Utils } from "../../Utils.sol";
import { WETH9Fixture } from "../weth9/WETH9Fixture.f.sol";

// forge-lint: disable-next-item(divide-before-multiply,mixed-case-function,reentrancy-no-eth)
contract Metadex03CLFixture is ConcentratedLiquidityFixture, WETH9Fixture, Metadex03Fixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    address internal metadex03PoolImplementation = 0x2000000000000000000000000000000000000001;
    // forge-lint: disable-next-line(mixed-case-variable)
    IMetadex03CLFactory internal metadex03CLFactory = IMetadex03CLFactory(0x2000000000000000000000000000000000000002);
    // forge-lint: disable-next-line(mixed-case-variable)
    IMetadex03CLGaugeFactory internal metadex03CLGaugeFactory;
    INonfungiblePositionManagerExtension internal metadex03PositionManager =
        INonfungiblePositionManagerExtension(0x2000000000000000000000000000000000000003);

    // The address foundry.toml links CLPoolNonSwapPath against.
    address internal constant CL_POOL_NON_SWAP_PATH = 0x3000000000000000000000000000000000000005;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        WETH9Fixture.setUp();
    }

    function deployMetadex03CL() internal {
        // Deploy CLPool.
        deployCodeTo("CLPoolNonSwapPath.sol:CLPoolNonSwapPath", CL_POOL_NON_SWAP_PATH);
        bytes memory args = abi.encode();
        deployCodeTo("Metadex03CLPoolExtension.sol", args, metadex03PoolImplementation);

        deployCodeTo("Metadex03CLFactoryExtension.sol", _clFactoryArgsMetadex03CL(), address(metadex03CLFactory));

        args = abi.encode(address(this), address(metadex03CLFactory), address(weth9), address(0), "", "");
        deployCodeTo("Metadex03NonfungiblePositionManagerExtension.sol", args, address(metadex03PositionManager));
    }

    /**
     * @notice Restages the CL contracts on the root chain.
     */
    function deployMetadex03CLOnRoot() internal {
        deployMetadex03Periphery(true);

        metadex03PoolImplementation = 0x2000000000000000000000000000000000000011;
        metadex03CLFactory = IMetadex03CLFactory(0x2000000000000000000000000000000000000012);
        metadex03PositionManager = INonfungiblePositionManagerExtension(0x2000000000000000000000000000000000000013);
        deployMetadex03CL();
    }

    function deployMetadex03CLGaugeFactory() internal {
        bytes memory args = abi.encode(
            address(leafVoter), metadex03GaugeManager, address(votingRewardsFactory), address(metadex03PositionManager)
        );
        // forge-lint: disable-next-item(encode-packed-collision)
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("Metadex03CLGaugeFactoryExtension.sol"),
            args,
            abi.encode(
                address(this),
                address(this),
                address(this),
                address(this),
                address(this),
                address(this),
                address(this),
                address(this)
            ),
            abi.encode(uint128(type(uint128).max - 1), uint128(1), uint128(type(uint128).max - 1), MAX_MIN_STAKE_BLOCKS)
        );
        metadex03CLGaugeFactory = IMetadex03CLGaugeFactory(Utils.deployBytecode(bytecode));

        // forge-lint: disable-next-line(reentrancy-no-eth)
        metadex03CLGaugeFactory.setPenaltyConfig(0, 0);
        metadex03CLGaugeFactory.setMaxShareCap(MAX_PIPS);

        vm.prank(metadex03ConfigAdmin);
        factoryRegistryMetadex03.registerFactories(address(metadex03CLGaugeFactory), address(metadex03CLFactory));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    function createPoolMetadex03CL(
        address token0,
        address token1,
        int24 tickSpacing,
        uint160 sqrtPriceX96,
        uint16 observationCardinality
    ) internal returns (ICLPoolExtension pool) {
        (token0, token1) = address(token0) < address(token1) ? (token0, token1) : (token1, token0);
        address poolAddress = metadex03CLFactory.createPool(token0, token1, tickSpacing, sqrtPriceX96);
        pool = ICLPoolExtension(poolAddress);
        pool.increaseObservationCardinalityNext(observationCardinality);
    }

    function createGaugeMetadex03CL(ICLPoolExtension pool) internal returns (IMetadex03CLGauge gauge) {
        gauge = createGaugeMetadex03CL(pool, true);
    }

    function createGaugeMetadex03CL(ICLPoolExtension pool, bool activate) internal returns (IMetadex03CLGauge gauge) {
        vm.startPrank(metadex03GaugeManager);
        (address gauge_, address rewards) = metadex03CLGaugeFactory.createGauge(address(pool), "");
        factoryRegistryMetadex03.registerGauge(gauge_, address(metadex03CLGaugeFactory), rewards, address(pool));
        leafVoter.registerGauge(gauge_, activate);
        vm.stopPrank();

        gauge = IMetadex03CLGauge(gauge_);
    }

    function addEmissionsToGaugeMetadex03CL(ICLPoolExtension pool_, address gauge, uint256 emissions) internal {
        addEmissionsToGauge(gauge, emissions);

        vm.prank(gauge);
        IMetadex03CLPoolExtension(address(pool_)).settleToBlock();
    }

    function _clFactoryArgsMetadex03CL() private view returns (bytes memory args) {
        IMetadex03CLFactory.ConstructorParams memory params;
        params.owner = address(this);
        params.swapFeeManager = address(this);
        params.unstakedFeeManager = address(this);
        params.voter = address(leafVoter);
        params.poolImplementation = metadex03PoolImplementation;
        params.positionManager = address(metadex03PositionManager);
        params.factoryRegistry = address(factoryRegistryMetadex03);
        params.discountRegistryManager = address(this);
        params.clPoolTapeManager = address(this);
        params.initialFeeTiers = _feeTiersMetadex03CL();
        args = abi.encode(params);
    }

    function _feeTiersMetadex03CL() private pure returns (IMetadex03CLFactory.FeeTier[] memory tiers) {
        tiers = new IMetadex03CLFactory.FeeTier[](7);
        tiers[0] = IMetadex03CLFactory.FeeTier({ tickSpacing: 1, fee: 100 });
        tiers[1] = IMetadex03CLFactory.FeeTier({ tickSpacing: 10, fee: 500 });
        tiers[2] = IMetadex03CLFactory.FeeTier({ tickSpacing: 50, fee: 3000 });
        tiers[3] = IMetadex03CLFactory.FeeTier({ tickSpacing: 100, fee: 10_000 });
        tiers[4] = IMetadex03CLFactory.FeeTier({ tickSpacing: 150, fee: 15_000 });
        tiers[5] = IMetadex03CLFactory.FeeTier({ tickSpacing: 200, fee: 20_000 });
        tiers[6] = IMetadex03CLFactory.FeeTier({ tickSpacing: 250, fee: 25_000 });
    }

    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        // forge-lint: disable-next-line(unsafe-typecast)
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    function setSwapHookMetadex03CL(address pool, address swapHook) internal {
        address[] memory pools = new address[](1);
        pools[0] = pool;
        address[] memory swapHooks = new address[](1);
        swapHooks[0] = swapHook;
        metadex03CLFactory.setPoolSwapHook(pools, swapHooks);
    }

    function addLiquidityMetadex03CL(
        ICLPoolExtension pool_,
        uint128 liquidity,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) internal returns (uint256 tokenId, uint256 amount0_, uint256 amount1_) {
        (uint160 sqrtPrice,,,,,) = pool_.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );

        return addLiquidityMetadex03CL(
            pool_, amount0, amount1, liquidityProvider_, tickLower, tickUpper, revertsOnZeroLiquidity
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function addLiquidityMetadex03CL(
        ICLPoolExtension pool_,
        uint256 amount0,
        uint256 amount1,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) internal returns (uint256 tokenId, uint256 amount0_, uint256 amount1_) {
        // Check if test should revert or be skipped when liquidity is zero.
        if (!revertsOnZeroLiquidity) {
            (uint160 sqrtPrice,,,,,) = pool_.slot0();
            uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
                sqrtPrice,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
            vm.assume(liquidity > 0);
        }

        address token0_ = pool_.token0();
        address token1_ = pool_.token1();
        int24 tickSpacing = pool_.tickSpacing();

        deal(token0_, liquidityProvider_, amount0, true);
        deal(token1_, liquidityProvider_, amount1, true);
        vm.startPrank(liquidityProvider_);
        ERC20(token0_).approve(address(metadex03PositionManager), type(uint256).max);
        ERC20(token1_).approve(address(metadex03PositionManager), type(uint256).max);
        (tokenId,, amount0_, amount1_) = metadex03PositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: token0_,
                token1: token1_,
                tickSpacing: tickSpacing,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: liquidityProvider_,
                deadline: type(uint256).max,
                sqrtPriceX96: 0
            })
        );
        vm.stopPrank();
    }

    function increaseLiquidityMetadex03CL(
        ICLPoolExtension pool,
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        bool revertsOnZeroLiquidity
    ) internal {
        // Check if test should revert or be skipped when liquidity is zero.
        (,, address token0, address token1,, int24 tickLower, int24 tickUpper,,,,,) =
            metadex03PositionManager.positions(tokenId);
        if (!revertsOnZeroLiquidity) {
            (uint160 sqrtPrice,,,,,) = pool.slot0();
            uint256 liquidity = LiquidityAmountsExtension.getLiquidityForAmounts(
                sqrtPrice,
                TickMath.getSqrtRatioAtTick(tickLower),
                TickMath.getSqrtRatioAtTick(tickUpper),
                amount0,
                amount1
            );
            vm.assume(liquidity > 0);
        }

        deal(token0, address(this), amount0, true);
        deal(token1, address(this), amount1, true);
        ERC20(token0).approve(address(metadex03PositionManager), type(uint256).max);
        ERC20(token1).approve(address(metadex03PositionManager), type(uint256).max);
        metadex03PositionManager.increaseLiquidity(
            INonfungiblePositionManagerExtension.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
    }

    function getAmountsMetadex03CL(uint256 id) internal view returns (uint256 amount0, uint256 amount1) {
        (uint256 principal0, uint256 principal1) = getPrincipalAmountsMetadex03CL(id);
        (uint256 fee0, uint256 fee1) = getFeeAmountsMetadex03CL(id);

        amount0 = principal0 + fee0;
        amount1 = principal1 + fee1;
    }

    function getPrincipalAmountsMetadex03CL(uint256 id) internal view returns (uint256 amount0, uint256 amount1) {
        (
            ,,
            address token0,
            address token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,,,,
        ) = metadex03PositionManager.positions(id);
        ICLPoolExtension pool = ICLPoolExtension(metadex03CLFactory.getPool(token0, token1, tickSpacing));
        (uint160 sqrtPrice,,,,,) = pool.slot0();

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );
    }

    function getFeeAmountsMetadex03CL(uint256 id) internal view returns (uint256 amount0, uint256 amount1) {
        (
            ,,
            address token0,
            address token1,
            int24 tickSpacing,
            int24 tickLower,
            int24 tickUpper,
            uint256 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint256 tokensOwed0,
            uint256 tokensOwed1
        ) = metadex03PositionManager.positions(id);

        (uint256 feeGrowthInside0CurrentX128, uint256 feeGrowthInside1CurrentX128) =
            getFeeGrowthInsideMetadex03CL(token0, token1, tickSpacing, tickLower, tickUpper);

        unchecked {
            amount0 = FullMath.mulDiv(
                feeGrowthInside0CurrentX128 - feeGrowthInside0LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed0;
            amount1 = FullMath.mulDiv(
                feeGrowthInside1CurrentX128 - feeGrowthInside1LastX128, liquidity, FixedPoint128.Q128
            ) + tokensOwed1;
        }
    }

    function getFeeGrowthInsideMetadex03CL(
        address token0,
        address token1,
        int24 tickSpacing,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) {
        ICLPoolExtension pool = ICLPoolExtension(metadex03CLFactory.getPool(token0, token1, tickSpacing));

        // To calculate the pending fees, the current tick has to be used, even if the pool would be unbalanced.
        (, int24 tickCurrent,,,,) = pool.slot0();
        (,,, uint256 lowerFeeGrowthOutside0X128, uint256 lowerFeeGrowthOutside1X128,,,,,) = pool.ticks(tickLower);
        (,,, uint256 upperFeeGrowthOutside0X128, uint256 upperFeeGrowthOutside1X128,,,,,) = pool.ticks(tickUpper);

        // Fee growth inside the range, can overflow without reverting.
        unchecked {
            if (tickCurrent < tickLower) {
                feeGrowthInside0X128 = lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 = lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else if (tickCurrent < tickUpper) {
                feeGrowthInside0X128 =
                    pool.feeGrowthGlobal0X128() - lowerFeeGrowthOutside0X128 - upperFeeGrowthOutside0X128;
                feeGrowthInside1X128 =
                    pool.feeGrowthGlobal1X128() - lowerFeeGrowthOutside1X128 - upperFeeGrowthOutside1X128;
            } else {
                feeGrowthInside0X128 = upperFeeGrowthOutside0X128 - lowerFeeGrowthOutside0X128;
                feeGrowthInside1X128 = upperFeeGrowthOutside1X128 - lowerFeeGrowthOutside1X128;
            }
        }
    }
}
