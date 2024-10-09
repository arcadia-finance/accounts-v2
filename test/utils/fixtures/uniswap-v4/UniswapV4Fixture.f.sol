/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Actions } from "../../../../lib/v4-periphery-fork/src/libraries/Actions.sol";
import { ActionConstants } from "../../../../lib/v4-periphery-fork/src/libraries/ActionConstants.sol";
import { BaseHookExtension } from "./extensions/BaseHookExtension.sol";
import { Currency } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/types/Currency.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { HookMockValid } from "../..//mocks/UniswapV4/BaseAM/HookMockValid.sol";
import { HookMockUnvalid } from "../../mocks/UniswapV4/BaseAM/HookMockUnvalid.sol";
import { Hooks } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/Hooks.sol";
import { IAllowanceTransfer } from "../../../../lib/v4-periphery-fork/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IPoolManager } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/interfaces/IPoolManager.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { Permit2Fixture } from "../../../utils/fixtures/permit2/Permit2Fixture.f.sol";
import { PoolKey } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { PoolManagerExtension } from "./extensions/PoolManagerExtension.sol";
import { PositionManagerExtension } from "./extensions/PositionManagerExtension.sol";
import { StateView } from "../../../../lib/v4-periphery-fork/src/lens/StateView.sol";
import { Test } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";

contract UniswapV4Fixture is Test, Permit2Fixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    BaseHookExtension internal validHook;
    BaseHookExtension internal unvalidHook;
    PoolManagerExtension internal poolManager;
    PositionManagerExtension internal positionManager;
    StateView internal stateView;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /// The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887_272;
    /// The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = 887_272;

    /// The minimum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_PRICE = 4_295_128_739;
    /// The maximum value that can be returned from #getSqrtPriceAtTick. Equivalent to getSqrtPriceAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_PRICE = 1_461_446_703_485_210_103_287_273_052_203_988_822_378_723_970_342;

    // A struct with the data to encode for position manager actions
    struct Plan {
        bytes actions;
        bytes[] params;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override(Permit2Fixture) {
        // Deploy Pool Manager
        poolManager = new PoolManagerExtension();

        // Deploy StateView
        stateView = new StateView(poolManager);

        // Deploy permit2
        Permit2Fixture.setUp();

        // Deploy Position Manager
        positionManager = new PositionManagerExtension(poolManager, IAllowanceTransfer(address(permit2)), 0);

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

        validHook = BaseHookExtension(deployHook(hooks, "HookMockValid.sol"));

        // Deploy unvalid hook
        hooks = new uint160[](2);
        hooks[0] = Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG;
        hooks[1] = Hooks.AFTER_REMOVE_LIQUIDITY_FLAG;
        unvalidHook = BaseHookExtension(deployHook(hooks, "HookMockUnvalid.sol"));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /* //////////////////////////////////////////////////////////////
                            POOL AND HOOK INIT
    ////////////////////////////////////////////////////////////// */
    function deployHook(uint160[] memory hooks, string memory hookInstance) public returns (address hookAddress) {
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

    /* //////////////////////////////////////////////////////////////
                         POSITION MANAGER ACTIONS
    ////////////////////////////////////////////////////////////// */

    function initPlan() internal pure returns (Plan memory plan) {
        return Plan({ actions: bytes(""), params: new bytes[](0) });
    }

    function addAction(Plan memory plan, uint256 action, bytes memory param) internal pure returns (Plan memory) {
        bytes memory actions = new bytes(plan.params.length + 1);
        bytes[] memory params = new bytes[](plan.params.length + 1);

        for (uint256 i; i < params.length - 1; i++) {
            // Copy from plan.
            params[i] = plan.params[i];
            actions[i] = plan.actions[i];
        }
        params[params.length - 1] = param;
        actions[params.length - 1] = bytes1(uint8(action));

        plan.actions = actions;
        plan.params = params;

        return plan;
    }

    /* //////////////////////////////////////////////////////////////
                                PERMIT 2
    ////////////////////////////////////////////////////////////// */

    function approvePositionManagerFor(address addr, address token) public {
        vm.startPrank(addr);
        ERC20(token).approve(address(permit2), type(uint256).max);
        permit2.approve(token, address(positionManager), type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    /* //////////////////////////////////////////////////////////////
                              SETTLE DELTAS
    ////////////////////////////////////////////////////////////// */

    function finalizeModifyLiquidityWithTake(Plan memory plan, PoolKey memory poolKey, address takeRecipient)
        internal
        pure
        returns (bytes memory)
    {
        plan = addAction(plan, Actions.TAKE, abi.encode(poolKey.currency0, takeRecipient, ActionConstants.OPEN_DELTA));
        plan = addAction(plan, Actions.TAKE, abi.encode(poolKey.currency1, takeRecipient, ActionConstants.OPEN_DELTA));
        return abi.encode(plan.actions, plan.params);
    }

    function finalizeModifyLiquidityWithClose(Plan memory plan, PoolKey memory poolKey)
        internal
        pure
        returns (bytes memory)
    {
        plan = addAction(plan, Actions.CLOSE_CURRENCY, abi.encode(poolKey.currency0));
        plan = addAction(plan, Actions.CLOSE_CURRENCY, abi.encode(poolKey.currency1));
        return abi.encode(plan.actions, plan.params);
    }

    /* //////////////////////////////////////////////////////////////
                               MODIFY LIQUIDITY
    ////////////////////////////////////////////////////////////// */

    function mintPosition(
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint128 amount0Max,
        uint128 amount1Max,
        address liquidityProvider
    ) internal returns (uint256 tokenId) {
        // Prepare the calldata for positionManager
        Plan memory planner = initPlan();
        bytes memory mintData;
        {
            planner = addAction(
                planner,
                Actions.MINT_POSITION,
                abi.encode(poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, liquidityProvider, "")
            );

            mintData = finalizeModifyLiquidityWithClose(planner, poolKey);
        }

        tokenId = positionManager.nextTokenId();

        (uint160 sqrtPriceX96,,,) = stateView.getSlot0(poolKey.toId());

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            uint128(liquidity)
        );

        // Deal and approve tokens
        address token0 = Currency.unwrap(poolKey.currency0);
        address token1 = Currency.unwrap(poolKey.currency1);

        // We can have some rounding issues between lib calculated amounts and contract, thus increase amount by 1
        // Todo : further investigate rounding diff
        deal(token0, liquidityProvider, amount0 + 1);
        deal(token1, liquidityProvider, amount1 + 1);

        // Approvals via permit2
        approvePositionManagerFor(liquidityProvider, token0);
        approvePositionManagerFor(liquidityProvider, token1);

        vm.prank(liquidityProvider);
        positionManager.modifyLiquidities(mintData, block.timestamp);
    }

    /*     function increaseLiquidityUniV3(
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
