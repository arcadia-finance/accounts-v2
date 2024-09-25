/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { BalanceDelta } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/types/BalanceDelta.sol";
import { BaseHookExtension } from "../../../fixtures/uniswap-v4/extensions/BaseHookExtension.sol";
import { Hooks } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/interfaces/IPoolManager.sol";
import { PoolKey } from "../../../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { PoolManagerExtension } from "../../../fixtures/uniswap-v4/extensions/PoolManagerExtension.sol";

contract HookMockUnvalid is BaseHookExtension {
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

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external virtual override returns (bytes4 selector) {
        return this.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external virtual override returns (bytes4, BalanceDelta) {
        BalanceDelta delta;
        return (this.afterRemoveLiquidity.selector, delta);
    }
}
