/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { BalanceDelta } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import { BaseHookExtension } from "../../../fixtures/uniswap-v4/extensions/BaseHookExtension.sol";
import { BeforeSwapDelta } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/BeforeSwapDelta.sol";
import { Hooks } from "../../../../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "../../../../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

contract HookMockValid is BaseHookExtension {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(IPoolManager manager) BaseHookExtension(manager) { }

    /*//////////////////////////////////////////////////////////////
                        HOOK PERMISSIONS
    //////////////////////////////////////////////////////////////*/

    // Set up hook permissions to return `true`
    // for the hook functions we are using
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: true,
            afterDonate: true,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeInitialize(address, PoolKey calldata, uint160) internal virtual override returns (bytes4) {
        return this.beforeInitialize.selector;
    }

    function _afterInitialize(address, PoolKey calldata, uint160, int24) internal virtual override returns (bytes4) {
        return this.afterInitialize.selector;
    }

    function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        internal
        virtual
        override
        returns (bytes4)
    {
        return this.beforeAddLiquidity.selector;
    }

    function _afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal virtual override returns (bytes4, BalanceDelta) {
        BalanceDelta delta;
        return (this.afterAddLiquidity.selector, delta);
    }

    function _beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        internal
        virtual
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        BeforeSwapDelta delta;
        return (this.beforeSwap.selector, delta, 0);
    }

    function _afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        virtual
        override
        returns (bytes4, int128)
    {
        return (this.afterSwap.selector, 0);
    }

    function _beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        internal
        virtual
        override
        returns (bytes4)
    {
        return this.beforeDonate.selector;
    }

    function _afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        internal
        virtual
        override
        returns (bytes4)
    {
        return this.afterDonate.selector;
    }
}
