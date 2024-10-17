/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AerodromeFixture } from "../aerodrome/AerodromeFixture.f.sol";
import { WETH9Fixture } from "../weth9/WETH9Fixture.f.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ICLFactoryExtension } from "./extensions/interfaces/ICLFactoryExtension.sol";
import { ICLGauge } from "../../../../src/asset-modules/Slipstream/interfaces/ICLGauge.sol";
import { ICLGaugeFactory } from "./interfaces/ICLGaugeFactory.sol";
import { ICLPoolExtension } from "./extensions/interfaces/ICLPoolExtension.sol";
import { INonfungiblePositionManagerExtension } from "./extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { LiquidityAmountsExtension } from "../uniswap-v3/extensions/libraries/LiquidityAmountsExtension.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";
import { Utils } from "../../Utils.sol";

contract SlipstreamFixture is WETH9Fixture, AerodromeFixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    address internal poolImplementation = 0xeC8E5342B19977B4eF8892e02D8DAEcfa1315831;
    ICLFactoryExtension internal cLFactory = ICLFactoryExtension(0x5e7BB104d84c7CB9B682AaC2F3d509f5F406809A);
    ICLGaugeFactory internal cLGaugeFactory;
    INonfungiblePositionManagerExtension internal slipstreamPositionManager =
        INonfungiblePositionManagerExtension(0x827922686190790b37229fd06084350E74485b72);

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        WETH9Fixture.setUp();
    }

    function deploySlipstream() internal {
        // Since Slipstream uses different a pragma version as us, we can't directly deploy the code
        // -> use getCode to get bytecode from artefacts and deploy directly.

        // Deploy CLPool.
        bytes memory args = abi.encode();
        deployCodeTo("CLPoolExtension.sol", args, poolImplementation);

        // Deploy the CLFactory.
        args = abi.encode(address(voter), poolImplementation);
        deployCodeTo("CLFactory.sol", args, address(cLFactory));

        // Deploy the NonfungiblePositionManager, pass zero address for the NonfungibleTokenPositionDescriptor.
        args = abi.encode(address(cLFactory), address(weth9), address(0), "", "");
        deployCodeTo("periphery/NonfungiblePositionManager.sol", args, address(slipstreamPositionManager));
    }

    function deployCLGaugeFactory() internal {
        // Deploy CLGauge implementation.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("CLGauge.sol"), args);
        address cLGauge_ = Utils.deployBytecode(bytecode);

        // Deploy the CLGaugeFactory.
        // Deploy the CLFactory.
        args = abi.encode(address(voter), cLGauge_);
        bytecode = abi.encodePacked(vm.getCode("CLGaugeFactory.sol"), args);
        address cLGaugeFactory_ = Utils.deployBytecode(bytecode);
        cLGaugeFactory = ICLGaugeFactory(cLGaugeFactory_);

        cLGaugeFactory.setNonfungiblePositionManager(address(slipstreamPositionManager));
        factoryRegistry.setFactoriesToPoolFactory(address(cLFactory), address(0), address(cLGaugeFactory));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    function createPoolCL(
        address token0,
        address token1,
        int24 tickSpacing,
        uint160 sqrtPriceX96,
        uint16 observationCardinality
    ) internal returns (ICLPoolExtension pool) {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        address poolAddress = cLFactory.createPool(token0, token1, tickSpacing, sqrtPriceX96); // Set initial price to lowest possible price.
        pool = ICLPoolExtension(poolAddress);
        pool.increaseObservationCardinalityNext(observationCardinality);
    }

    function createGaugeCL(ICLPoolExtension pool) internal returns (ICLGauge gauge) {
        vm.prank(address(voter));
        gauge = ICLGauge(cLGaugeFactory.createGauge(address(0), address(pool), address(0), AERO, true));

        voter.setGauge(address(gauge));
        voter.setAlive(address(gauge), true);
    }

    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        int24 minTick = (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
        int24 maxTick = (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
        uint24 numTicks = uint24((maxTick - minTick) / tickSpacing) + 1;
        return type(uint128).max / numTicks;
    }

    function addLiquidityCL(
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

        return addLiquidityCL(pool_, amount0, amount1, liquidityProvider_, tickLower, tickUpper, revertsOnZeroLiquidity);
    }

    function addLiquidityCL(
        ICLPoolExtension pool_,
        uint256 amount0,
        uint256 amount1,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) internal returns (uint256 tokenId, uint256 amount0_, uint256 amount1_) {
        // Check if test should revert or be skipped when liquidity is zero.
        // This is hard to check with assumes of the fuzzed inputs due to rounding errors.
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
        ERC20(token0_).approve(address(slipstreamPositionManager), type(uint256).max);
        ERC20(token1_).approve(address(slipstreamPositionManager), type(uint256).max);
        (tokenId,, amount0_, amount1_) = slipstreamPositionManager.mint(
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

    function increaseLiquidityCL(
        ICLPoolExtension pool,
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        bool revertsOnZeroLiquidity
    ) internal {
        // Check if test should revert or be skipped when liquidity is zero.
        // This is hard to check with assumes of the fuzzed inputs due to rounding errors.
        (,, address token0, address token1,, int24 tickLower, int24 tickUpper,,,,,) =
            slipstreamPositionManager.positions(tokenId);
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
        ERC20(token0).approve(address(slipstreamPositionManager), type(uint256).max);
        ERC20(token1).approve(address(slipstreamPositionManager), type(uint256).max);
        slipstreamPositionManager.increaseLiquidity(
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
}
