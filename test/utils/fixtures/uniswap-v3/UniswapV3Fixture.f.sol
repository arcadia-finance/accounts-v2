/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { WETH9Fixture } from "../weth9/WETH9Fixture.f.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { LiquidityAmountsExtension } from "./extensions/libraries/LiquidityAmountsExtension.sol";
import { INonfungiblePositionManagerExtension } from "./extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { IUniswapV3Factory } from "./extensions/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3PoolExtension } from "./extensions/interfaces/IUniswapV3PoolExtension.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";
import { Utils } from "../../../utils/Utils.sol";

contract UniswapV3Fixture is WETH9Fixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IUniswapV3Factory internal uniswapV3Factory;
    INonfungiblePositionManagerExtension internal nonfungiblePositionManager =
        INonfungiblePositionManagerExtension(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        WETH9Fixture.setUp();

        // Since Uniswap uses different a pragma version as us, we can't directly deploy the code
        // -> use getCode to get bytecode from artefacts and deploy directly.

        // Deploy the uniswapV3Factory.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV3FactoryExtension.sol"), args);
        address uniswapV3Factory_ = Utils.deployBytecode(bytecode);
        uniswapV3Factory = IUniswapV3Factory(uniswapV3Factory_);
        // Add fee 100 with tickspacing 1.
        uniswapV3Factory.enableFeeAmount(100, 1);

        // Deploy the NonfungiblePositionManager.
        args = abi.encode(uniswapV3Factory_, address(weth9), address(0));
        deployCodeTo("NonfungiblePositionManagerExtension.sol", args, address(nonfungiblePositionManager));

        // Get the bytecode of the UniswapV3PoolExtension.
        args = abi.encode();
        bytecode = abi.encodePacked(vm.getCode("UniswapV3PoolExtension.sol"), args);
        bytes32 poolExtensionInitCodeHash = keccak256(bytecode);

        // Overwrite constant in bytecode of NonfungiblePositionManager.
        // -> Replace the code hash of UniswapV3Pool.sol with the code hash of UniswapV3PoolExtension.sol
        bytes32 POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytecode = address(nonfungiblePositionManager).code;
        bytecode = Utils.veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);
        vm.etch(address(nonfungiblePositionManager), bytecode);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function createPoolUniV3(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96,
        uint16 observationCardinality
    ) internal returns (IUniswapV3PoolExtension uniV3Pool_) {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        address poolAddress =
            nonfungiblePositionManager.createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96);
        uniV3Pool_ = IUniswapV3PoolExtension(poolAddress);
        uniV3Pool_.increaseObservationCardinalityNext(observationCardinality);
    }

    function addLiquidityUniV3(
        IUniswapV3PoolExtension pool,
        uint128 liquidity,
        address liquidityProvider_,
        int24 tickLower,
        int24 tickUpper,
        bool revertsOnZeroLiquidity
    ) internal returns (uint256 tokenId, uint256 amount0_, uint256 amount1_) {
        (uint160 sqrtPrice,,,,,,) = pool.slot0();

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPrice, TickMath.getSqrtRatioAtTick(tickLower), TickMath.getSqrtRatioAtTick(tickUpper), liquidity
        );

        return
            addLiquidityUniV3(pool, amount0, amount1, liquidityProvider_, tickLower, tickUpper, revertsOnZeroLiquidity);
    }

    function addLiquidityUniV3(
        IUniswapV3PoolExtension pool,
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

        deal(token0, liquidityProvider_, amount0, true);
        deal(token1, liquidityProvider_, amount1, true);

        vm.startPrank(liquidityProvider_);
        ERC20(token0).approve(address(nonfungiblePositionManager), type(uint256).max);
        ERC20(token1).approve(address(nonfungiblePositionManager), type(uint256).max);
        (tokenId,, amount0_, amount1_) = nonfungiblePositionManager.mint(
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

    function increaseLiquidityUniV3(
        IUniswapV3PoolExtension pool,
        uint256 tokenId,
        uint256 amount0,
        uint256 amount1,
        bool revertsOnZeroLiquidity
    ) internal {
        // Check if test should revert or be skipped when liquidity is zero.
        // This is hard to check with assumes of the fuzzed inputs due to rounding errors.
        (,, address token0, address token1,, int24 tickLower, int24 tickUpper,,,,,) =
            nonfungiblePositionManager.positions(tokenId);
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

        deal(token0, address(this), amount0, true);
        deal(token1, address(this), amount1, true);
        ERC20(token0).approve(address(nonfungiblePositionManager), type(uint256).max);
        ERC20(token1).approve(address(nonfungiblePositionManager), type(uint256).max);
        nonfungiblePositionManager.increaseLiquidity(
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

    function isWithinAllowedRange(int24 tick) internal pure returns (bool) {
        return (tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick))) <= uint256(uint24(TickMath.MAX_TICK));
    }
}
