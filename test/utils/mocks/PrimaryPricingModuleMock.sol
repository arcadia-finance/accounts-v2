// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { AbstractPrimaryPricingModuleExtension } from "../Extensions.sol";

contract PrimaryPricingModuleMock is AbstractPrimaryPricingModuleExtension {
    // Price is 1 by default
    uint256 usdValueExposureToUnderlyingAsset = 1;

    constructor(address mainRegistry_, address oracleHub_, uint256 assetType_)
        AbstractPrimaryPricingModuleExtension(mainRegistry_, oracleHub_, assetType_)
    { }

    function isAllowed(address asset, uint256) public view override returns (bool) {
        return inPricingModule[asset];
    }

    function setPrice(uint256 usdValueExposureToUnderlyingAsset_) public {
        usdValueExposureToUnderlyingAsset = usdValueExposureToUnderlyingAsset_;
    }

    // The function below is only needed in the case of testing for the "AbstractDerivedPricingModule", in order for the Primary Asset to return a value
    // getValue() will be tested separately per PM.
    function getValue(GetValueInput memory)
        public
        view
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        // we assume a price of 1 for this testing purpose
        valueInUsd = usdValueExposureToUnderlyingAsset;
        collateralFactor = 0;
        liquidationFactor = 0;
    }
}
