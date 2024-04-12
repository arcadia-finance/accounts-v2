// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { AssetModuleExtension } from "../../extensions/AssetModuleExtension.sol";

contract AssetModuleMock is AssetModuleExtension {
    constructor(address registry_, uint256 assetType_) AssetModuleExtension(registry_, assetType_) { }

    bool internal isAllowed_;

    function isAllowed(address, uint256) public view override returns (bool) {
        return isAllowed_;
    }

    function setIsAllowedResponse(bool response) public {
        isAllowed_ = response;
    }

    function getRiskFactors(address creditor, address asset, uint256 assetId)
        external
        view
        virtual
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    { }

    function getValue(address creditor, address asset, uint256 assetId, uint256 assetAmount)
        public
        view
        override
        returns (uint256, uint256, uint256)
    { }

    function processDirectDeposit(address, address, uint256, uint256)
        public
        pure
        override
        returns (uint256 recursiveCalls)
    {
        recursiveCalls = 1;
    }

    function processIndirectDeposit(
        address creditor,
        address asset,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override returns (uint256, uint256) { }

    function processDirectWithdrawal(address, address, uint256, uint256) public view override { }

    function processIndirectWithdrawal(
        address creditor,
        address asset,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override returns (uint256) { }
}
