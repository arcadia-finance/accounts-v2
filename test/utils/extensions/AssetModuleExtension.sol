/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetModule } from "../../../src/asset-modules/abstracts/AbstractAM.sol";

abstract contract AssetModuleExtension is AssetModule {
    constructor(address registry_, uint256 assetType_) AssetModule(registry_, assetType_) { }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}
