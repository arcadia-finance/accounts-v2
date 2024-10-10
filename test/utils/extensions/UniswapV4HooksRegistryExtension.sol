/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { UniswapV4HooksRegistry } from "../../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

contract UniswapV4HooksRegistryExtension is UniswapV4HooksRegistry {
    constructor(address registry_, address positionManager, address defaultUniswapV4AM)
        UniswapV4HooksRegistry(registry_, positionManager, defaultUniswapV4AM)
    { }

    function getPositionManager() public returns (address positionManager) {
        return address(POSITION_MANAGER);
    }

    function setAssetModule(address assetModule) public {
        isAssetModule[assetModule] = true;
    }
}
