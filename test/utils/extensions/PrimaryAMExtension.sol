/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { PrimaryAM } from "../../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";

abstract contract PrimaryAMExtension is PrimaryAM {
    constructor(address registry_, uint256 assetType_) PrimaryAM(registry_, assetType_) { }

    function setExposure(
        address creditor,
        address asset,
        uint256 assetId,
        uint112 lastExposureAsset,
        uint112 maxExposure
    ) public {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        riskParams[creditor][assetKey].lastExposureAsset = lastExposureAsset;
        riskParams[creditor][assetKey].maxExposure = maxExposure;
    }
}
