/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { BaseHookExtension } from "./extensions/BaseHookExtension.sol";
import { Currency } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/types/Currency.sol";
import { HookMockValid } from "../..//mocks/UniswapV4/BaseAM/HookMockValid.sol";
import { HookMockUnvalid } from "../../mocks/UniswapV4/BaseAM/HookMockUnvalid.sol";
import { Hooks } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/Hooks.sol";
import { IAllowanceTransfer } from "../../../../lib/v4-periphery-fork/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { PoolKey } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { PoolManagerExtension } from "./extensions/PoolManagerExtension.sol";
import { PositionManagerExtension } from "./extensions/PositionManagerExtension.sol";
import { StateViewExtension } from "./extensions/StateViewExtension.sol";
import { Test } from "../../../../lib/forge-std/src/Test.sol";

contract UniswapV4Fixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    PoolManagerExtension internal poolManager;
    PositionManagerExtension internal positionManager;
    StateViewExtension internal stateView;
    BaseHookExtension internal validHook;
    BaseHookExtension internal unvalidHook;

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

    function setUp() public virtual {
        // Deploy Pool Manager
        poolManager = new PoolManagerExtension();

        // Deploy StateView contract
        stateView = new StateViewExtension(poolManager);

        // Deploy Position Manager
        positionManager = new PositionManagerExtension(poolManager, IAllowanceTransfer(address(0)), 0);

        // Deploy mocked hooks (to get contrac instance used below)
        validHook = new HookMockValid(poolManager);
        unvalidHook = new HookMockUnvalid(poolManager);

        // Deploy valid hook
        uint160[] memory hooks = new uint160[](8);
        hooks[0] = Hooks.BEFORE_INITIALIZE_FLAG;
        hooks[1] = Hooks.AFTER_INITIALIZE_FLAG;
        hooks[2] = Hooks.BEFORE_ADD_LIQUIDITY_FLAG;
        hooks[3] = Hooks.AFTER_ADD_LIQUIDITY_FLAG;
        hooks[4] = Hooks.BEFORE_SWAP_FLAG;
        hooks[5] = Hooks.AFTER_SWAP_FLAG;
        hooks[6] = Hooks.BEFORE_DONATE_FLAG;
        hooks[7] = Hooks.AFTER_DONATE_FLAG;

        validHook = BaseHookExtension(deployHook(hooks, "HookMockValid.sol", true));

        // Deploy unvalid hook
        hooks = new uint160[](2);
        hooks[0] = Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG;
        hooks[1] = Hooks.AFTER_REMOVE_LIQUIDITY_FLAG;
        unvalidHook = BaseHookExtension(deployHook(hooks, "HookMockUnvalid.sol", false));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function deployHook(uint160[] memory hooks, string memory hookInstance, bool validHook_)
        public
        returns (address hookAddress)
    {
        // Set flags for hooks to implement
        uint160 flags;
        for (uint256 i; i < hooks.length; i++) {
            flags = flags | hooks[i];
        }

        // Here we deploy to an address ending with valid bits representing active hooks.
        // We won't use HookMiner for testing to avoid waiting time to find the right salt.
        hookAddress = address(flags);

        deployCodeTo(hookInstance, abi.encode(poolManager), hookAddress);

        // Validate hook address
        BaseHookExtension(hookAddress).validateHookExtensionAddress(BaseHookExtension(hookAddress));
    }

    function initializePool(
        address token0,
        address token1,
        uint160 sqrtPriceX96,
        address hook,
        uint24 fee,
        int24 tickSpacing
    ) public returns (PoolKey memory poolKey) {
        Currency currency0;
        Currency currency1;
        if (token0 > token1) {
            (currency0, currency1) = (Currency.wrap(address(token1)), Currency.wrap(address(token0)));
        } else {
            (currency0, currency1) = (Currency.wrap(address(token0)), Currency.wrap(address(token1)));
        }

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: BaseHookExtension(hook)
        });

        // Initialize pool
        poolManager.initialize(poolKey, sqrtPriceX96, "");
    }
    /* 
    function addLiquidity(
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
    }  */

    function isWithinAllowedRange(int24 tick) internal pure returns (bool) {
        return (tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick))) <= uint256(uint24(MAX_TICK));
    }
}
