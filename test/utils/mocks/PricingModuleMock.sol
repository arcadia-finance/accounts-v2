// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AbstractPricingModuleExtension } from "../Extensions.sol";

contract PricingModuleMock is AbstractPricingModuleExtension {
    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_, address riskManager_)
        AbstractPricingModuleExtension(mainRegistry_, oracleHub_, assetType_, riskManager_)
    { }

    function isAllowed(address asset, uint256) public view override returns (bool) { }

    function getValue(GetValueInput memory input) public view override returns (uint256, uint256, uint256) { }

    function processDirectDeposit(address asset, uint256 id, uint256 amount) public override { }

    function processIndirectDeposit(
        address asset,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public override returns (bool, uint256) { }

    function processDirectWithdrawal(address asset, uint256 id, uint256 amount) external override { }

    function processIndirectWithdrawal(
        address asset,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) external override returns (bool, uint256) { }
}