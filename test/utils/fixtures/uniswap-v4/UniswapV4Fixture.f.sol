/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { PoolManagerExtension } from "./extensions/PoolManagerExtension.sol";
import { PositionManagerExtension } from "./extensions/PositionManagerExtension.sol";
import { StateViewExtension } from "./extensions/StateViewExtension.sol";

contract UniswapV4Fixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    PoolManagerExtension internal poolManager;
    PositionManagerExtension internal positionManager;
    StateViewExtension internal stateView;

    /// The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887_272;
    /// The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = 887_272;

    /// The minimum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_PRICE = 4_295_128_739;
    /// The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_PRICE = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        // Deploy Pool Manager
        poolManager = new PoolManager();

        // Deploy StateView contract
        stateView = new StateView(poolManager);

        // Deploy Position Manager
        positionManager = new PositionManager(poolManager, IAllowanceTransfer(address(0)), 0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function deployHook(uint160[] memory hooks, string memory hookInstance) public returns (address arbitraryAddress) {
        // Set flags for hooks to implement
        uint160 flags;
        for (uint256 i; i < hooks.length; i++) {
            flags = flags | hooks[i];
        }

        // Here we deploy to an arbitrary address to avoid waiting to find the right salt with the HookFinder.
        arbitraryAddress = address(flags);

        deployCodeTo(hookInstance, abi.encode(poolManager), arbitraryAddress);
    }

    function initializePool(
        address token0,
        address token1,
        uint160 sqrtPriceX96,
        address hook,
        uint24 fee,
        int24 tickSpacing
    ) public returns (PoolKey memory poolKey) {
        if (address(token0) > address(token1)) {
            (token0, token1) = (Currency.wrap(address(token1)), Currency.wrap(address(token0)));
        } else {
            (token0, token1) = (Currency.wrap(address(token0)), Currency.wrap(address(token1)));
        }

        poolKey =
            PoolKey({ currency0: token0, currency1: token1, fee: fee, tickSpacing: tickSpacing, hooks: BaseHook(hook) });

        // Initialize pool
        poolManager.initialize(poolKey, sqrtPriceX96, "");
    }

    /*     function createPoolUniV3(
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
    } */

    function isWithinAllowedRange(int24 tick) internal pure returns (bool) {
        return (tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick))) <= uint256(uint24(MAX_TICK));
    }
}
