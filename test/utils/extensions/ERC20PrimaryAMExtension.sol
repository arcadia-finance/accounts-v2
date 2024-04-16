/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20PrimaryAM } from "../../../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";

contract ERC20PrimaryAMExtension is ERC20PrimaryAM {
    constructor(address registry_) ERC20PrimaryAM(registry_) { }

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
