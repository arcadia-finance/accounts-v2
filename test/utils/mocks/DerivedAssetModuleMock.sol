// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { AbstractDerivedAssetModuleExtension } from "../Extensions.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";

contract DerivedAssetModuleMock is AbstractDerivedAssetModuleExtension {
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    uint256 internal underlyingAssetAmount;
    bool internal returnRateUnderlyingAssetToUsd;
    uint256 internal rateUnderlyingAssetToUsd;

    constructor(address registry_, uint256 assetType_) AbstractDerivedAssetModuleExtension(registry_, assetType_) { }

    function isAllowed(address asset, uint256) public view override returns (bool) { }

    function setUnderlyingAssetsAmount(uint256 underlyingAssetAmount_) public {
        underlyingAssetAmount = underlyingAssetAmount_;
    }

    function setRateUnderlyingAssetToUsd(uint256 rateUnderlyingAssetToUsd_) public {
        rateUnderlyingAssetToUsd = rateUnderlyingAssetToUsd_;
        returnRateUnderlyingAssetToUsd = true;
    }

    function addAsset(
        address asset,
        uint256 assetId,
        address[] memory underlyingAssets_,
        uint256[] memory underlyingAssetIds
    ) public {
        require(!inAssetModule[asset], "ADPME_AA: already added");
        inAssetModule[asset] = true;

        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](underlyingAssets_.length);
        for (uint256 i; i < underlyingAssets_.length;) {
            underlyingAssetKeys[i] = _getKeyFromAsset(underlyingAssets_[i], underlyingAssetIds[i]);
            ++i;
        }
        assetToUnderlyingAssets[assetKey] = underlyingAssetKeys;
    }

    function _getUnderlyingAssetsAmounts(address, bytes32, uint256, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmount, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        underlyingAssetsAmount = new uint256[](1);
        underlyingAssetsAmount[0] = underlyingAssetAmount;

        // If rateUnderlyingAssetToUsd is set, also return rateUnderlyingAssetsToUsd.
        if (returnRateUnderlyingAssetToUsd) {
            rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](1);
            rateUnderlyingAssetsToUsd[0].assetValue = rateUnderlyingAssetToUsd;
        }

        return (underlyingAssetsAmount, rateUnderlyingAssetsToUsd);
    }

    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssets)
    {
        underlyingAssets = assetToUnderlyingAssets[assetKey];
    }
}
