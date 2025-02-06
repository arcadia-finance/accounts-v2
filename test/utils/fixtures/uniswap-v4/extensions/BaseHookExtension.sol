// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import { BaseHook } from "../../../../../lib/v4-periphery/src/base/hooks/BaseHook.sol";
import { Hooks } from "../../../../../lib/v4-periphery/lib/v4-core/src/libraries/Hooks.sol";
import { PoolManagerExtension } from "./PoolManagerExtension.sol";

abstract contract BaseHookExtension is BaseHook {
    constructor(PoolManagerExtension poolManager_) BaseHook(poolManager_) { }

    function validateHookAddress(BaseHook _this) internal pure virtual override { }

    function validateHookExtensionAddress(BaseHookExtension _this) external pure {
        Hooks.validateHookPermissions(_this, getHookPermissions());
    }

    function getHookPermissions() public pure virtual override returns (Hooks.Permissions memory);
}
