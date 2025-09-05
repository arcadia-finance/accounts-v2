// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { BaseHook } from "../../../../../lib/v4-periphery/src/utils/BaseHook.sol";
import { Hooks } from "../../../../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { IPoolManager } from "../../../../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";

abstract contract BaseHookExtension is BaseHook {
    constructor(IPoolManager poolManager_) BaseHook(poolManager_) { }

    function validateHookAddress(BaseHook _this) internal pure virtual override { }

    function validateHookExtensionAddress(BaseHookExtension _this) external pure {
        Hooks.validateHookPermissions(_this, getHookPermissions());
    }

    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory);
}
