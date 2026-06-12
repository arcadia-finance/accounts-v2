/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";
import { DerivedAM } from "../../../src/asset-modules/abstracts/AbstractDerivedAM.sol";

abstract contract DerivedAMExtension is DerivedAM {
    constructor(address owner_, address registry_, uint256 assetType_) DerivedAM(owner_, registry_, assetType_) { }

    function getAssetExposureLast(address creditor, bytes32 assetKey)
        external
        view
        returns (uint128 lastExposureAsset, uint128 lastUsdExposureAsset)
    {
        lastExposureAsset = lastExposuresAsset[creditor][assetKey].lastExposureAsset;
        lastUsdExposureAsset = lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset;
    }

    function getExposureAssetToUnderlyingAssetsLast(address creditor, bytes32 assetKey, uint256 index)
        external
        view
        returns (uint256 exposureAssetToUnderlyingAssetsLast_)
    {
        exposureAssetToUnderlyingAssetsLast_ = lastExposureAssetToUnderlyingAsset[creditor][assetKey][index];
    }

    function setUsdExposureProtocol(address creditor, uint112 maxUsdExposureProtocol_, uint112 usdExposureProtocol_)
        public
    {
        riskParams[creditor].maxUsdExposureProtocol = maxUsdExposureProtocol_;
        riskParams[creditor].lastUsdExposureProtocol = usdExposureProtocol_;
    }

    function setAssetInformation(
        address creditor,
        address asset,
        uint256 assetId,
        address,
        uint256,
        uint112 exposureAssetLast,
        uint112 lastUsdExposureAsset,
        uint128 exposureAssetToUnderlyingAssetLast
    ) public {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        lastExposuresAsset[creditor][assetKey].lastExposureAsset = exposureAssetLast;
        lastExposuresAsset[creditor][assetKey].lastUsdExposureAsset = lastUsdExposureAsset;
        lastExposureAssetToUnderlyingAsset[creditor][assetKey][0] = exposureAssetToUnderlyingAssetLast;
    }

    function getRateUnderlyingAssetsToUsd(address creditor, bytes32[] memory underlyingAssetKeys)
        public
        view
        returns (AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
    }

    function processDeposit(address creditor, bytes32 assetKey, uint256 exposureAsset)
        public
        returns (uint256 usdExposureAsset)
    {
        (, usdExposureAsset) = _processDeposit(exposureAsset, creditor, assetKey);
    }

    function getAndUpdateExposureAsset(address creditor, bytes32 assetKey, int256 deltaAsset)
        public
        returns (uint256 exposureAsset)
    {
        exposureAsset = _getAndUpdateExposureAsset(creditor, assetKey, deltaAsset);
    }

    function processWithdrawal(address creditor, bytes32 assetKey, uint256 exposureAsset)
        public
        returns (uint256 usdExposureAsset)
    {
        usdExposureAsset = _processWithdrawal(creditor, assetKey, exposureAsset);
    }

    function getAssetFromKey(bytes32 key) public view returns (address asset, uint256 assetId) {
        (asset, assetId) = _getAssetFromKey(key);
    }

    function getKeyFromAsset(address asset, uint256 assetId) public view returns (bytes32 key) {
        (key) = _getKeyFromAsset(asset, assetId);
    }
}
