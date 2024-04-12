/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { StandardERC4626AM } from "../mocks/asset-modules/StandardERC4626AM.sol";

contract ERC4626AMExtension is StandardERC4626AM {
    constructor(address registry_) StandardERC4626AM(registry_) { }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 exposureAsset,
        bytes32[] memory underlyingAssetKeys
    )
        public
        view
        returns (
            uint256[] memory exposureAssetToUnderlyingAssets,
            AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
        )
    {
        (exposureAssetToUnderlyingAssets, rateUnderlyingAssetsToUsd) =
            _getUnderlyingAssetsAmounts(creditor, assetKey, exposureAsset, underlyingAssetKeys);
    }

    function getUnderlyingAssets(bytes32 assetKey) public view returns (bytes32[] memory underlyingAssets) {
        return _getUnderlyingAssets(assetKey);
    }
}
