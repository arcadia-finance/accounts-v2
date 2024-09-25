/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { BalanceDelta } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/types/BalanceDelta.sol";
import { BaseHookExtension } from "../../../fixtures/uniswap-v4/extensions/BaseHookExtension.sol";
import { BeforeSwapDelta } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/types/BeforeSwapDelta.sol";
import { Hooks } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { PoolManagerExtension } from "../../../fixtures/uniswap-v4/extensions/PoolManagerExtension.sol";

contract HookMockValid is BaseHookExtension {
    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(PoolManagerExtension manager) BaseHookExtension(manager) { }

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

    function beforeInitialize(address, PoolKey calldata, uint160, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        return this.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        return this.afterInitialize.selector;
    }

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        return this.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual override returns (bytes4, BalanceDelta) {
        BalanceDelta delta;
        return (this.afterAddLiquidity.selector, delta);
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        virtual
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        BeforeSwapDelta delta;
        return (this.beforeSwap.selector, delta, 0);
    }

    function afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        virtual
        override
        returns (bytes4, int128)
    {
        return (this.afterSwap.selector, 0);
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        return this.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        virtual
        override
        returns (bytes4)
    {
        return this.afterDonate.selector;
    }
}
