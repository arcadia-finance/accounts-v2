/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { UniswapV4HooksRegistry } from "../../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

contract UniswapV4HooksRegistryExtension is UniswapV4HooksRegistry {
    constructor(address registry_, address positionManager) UniswapV4HooksRegistry(registry_, positionManager) { }

    function getPositionManager() public view returns (address positionManager) {
        return address(POSITION_MANAGER);
    }

    function setAssetModule(address assetModule) public {
        isAssetModule[assetModule] = true;
    }

    function setHooksToAssetModule(address hooks, address assetModule) public {
        hooksToAssetModule[hooks] = assetModule;
    }
}
