/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { NativeTokenAM } from "../../../src/asset-modules/native-token/NativeTokenAM.sol";

contract NativeTokenAMExtension is NativeTokenAM {
    constructor(address registry_) NativeTokenAM(registry_) { }

    function getAssetFromKey(bytes32 key) public pure returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public pure returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }

    function setExposure(address creditor, address asset, uint112 lastExposureAsset, uint112 maxExposure) public {
        bytes32 assetKey = _getKeyFromAsset(asset, 0);
        riskParams[creditor][assetKey].lastExposureAsset = lastExposureAsset;
        riskParams[creditor][assetKey].maxExposure = maxExposure;
    }
}
