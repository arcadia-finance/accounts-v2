// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AbstractDerivedPricingModuleExtension } from "../Extensions.sol";

contract DerivedPricingModuleMock is AbstractDerivedPricingModuleExtension {
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    uint256 public underlyingAssetsAmount;

    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        AbstractDerivedPricingModuleExtension(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    function isAllowed(address asset, uint256) public view override returns (bool) { }

    function setUnderlyingAssetsAmount(uint256 underlyingAssetsAmount_) public {
        underlyingAssetsAmount = underlyingAssetsAmount_;
    }

    function addAsset(
        address asset,
        uint256 assetId,
        address[] memory underlyingAssets_,
        uint256[] memory underlyingAssetIds
    ) public {
        require(!inPricingModule[asset], "ADPME_AA: already added");
        inPricingModule[asset] = true;
        assetsInPricingModule.push(asset);

        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32[] memory underlyingAssetKeys = new bytes32[](underlyingAssets_.length);
        for (uint256 i; i < underlyingAssets_.length;) {
            underlyingAssetKeys[i] = _getKeyFromAsset(underlyingAssets_[i], underlyingAssetIds[i]);
            ++i;
        }
        assetToUnderlyingAssets[assetKey] = underlyingAssetKeys;
    }

    function _getUnderlyingAssetsAmounts(bytes32, uint256, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmount_, uint256[] memory rateUnderlyingAssetsToUsd)
    {
        underlyingAssetsAmount_ = new uint256[](1);
        underlyingAssetsAmount_[0] = underlyingAssetsAmount;

        return (underlyingAssetsAmount_, rateUnderlyingAssetsToUsd);
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
