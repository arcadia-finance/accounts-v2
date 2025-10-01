/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { BalanceDelta } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/BalanceDelta.sol";
import { BaseHookExtension } from "../../../fixtures/uniswap-v4/extensions/BaseHookExtension.sol";
import { Hooks } from "../../../../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "../../../../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import { ModifyLiquidityParams } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/PoolOperation.sol";
import { PoolKey } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

contract HookMockUnvalid is BaseHookExtension {
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
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: false,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        virtual
        override
        returns (bytes4 selector)
    {
        return this.beforeRemoveLiquidity.selector;
    }

    function _afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) internal virtual override returns (bytes4, BalanceDelta) {
        BalanceDelta delta;
        return (this.afterRemoveLiquidity.selector, delta);
    }
}
