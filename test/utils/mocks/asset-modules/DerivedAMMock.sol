// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { AbstractDerivedAMExtension } from "../../Extensions.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IRegistry } from "../../../../src/asset-modules/interfaces/IRegistry.sol";

contract DerivedAMMock is AbstractDerivedAMExtension {
    using FixedPointMathLib for uint256;

    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;

    uint256 internal underlyingAssetAmount;
    bool internal returnRateUnderlyingAssetToUsd;
    uint256 internal rateUnderlyingAssetToUsd;

    constructor(address registry_, uint256 assetType_) AbstractDerivedAMExtension(registry_, assetType_) { }

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

    /**
     * @notice Returns the risk factors of an asset for a Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return collateralFactor The collateral factor of the asset for the Creditor, 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for the Creditor, 4 decimals precision.
     */
    function getRiskFactors(address creditor, address asset, uint256 assetId)
        external
        view
        virtual
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    {
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(_getKeyFromAsset(asset, assetId));

        uint256 length = underlyingAssetKeys.length;
        address[] memory assets = new address[](length);
        uint256[] memory assetIds = new uint256[](length);
        for (uint256 i; i < length; ++i) {
            (assets[i], assetIds[i]) = _getAssetFromKey(underlyingAssetKeys[i]);
        }

        (uint16[] memory collateralFactors, uint16[] memory liquidationFactors) =
            IRegistry(REGISTRY).getRiskFactors(creditor, assets, assetIds);

        // Initialize risk factors with first elements of array.
        collateralFactor = collateralFactors[0];
        liquidationFactor = liquidationFactors[0];

        // Keep the lowest risk factor of all underlying assets.
        for (uint256 i = 1; i < length; ++i) {
            if (collateralFactor > collateralFactors[i]) collateralFactor = collateralFactors[i];

            if (liquidationFactor > liquidationFactors[i]) liquidationFactor = liquidationFactors[i];
        }

        // Cache riskFactor
        uint256 riskFactor = riskParams[creditor].riskFactor;

        // Lower risk factors with the protocol wide risk factor.
        collateralFactor = uint16(riskFactor.mulDivDown(collateralFactor, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(riskFactor.mulDivDown(liquidationFactor, AssetValuationLib.ONE_4));
    }

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @param rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
     * @dev We take the most conservative (lowest) risk factor of all underlying assets.
     */
    function _calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    )
        internal
        view
        virtual
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        // Initialize variables with first elements of array.
        // "rateUnderlyingAssetsToUsd" is the USD value with 18 decimals precision for 10**18 tokens of Underlying Asset.
        // To get the USD value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
        // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
        valueInUsd = underlyingAssetsAmounts[0].mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, 1e18);

        collateralFactor = rateUnderlyingAssetsToUsd[0].collateralFactor;
        liquidationFactor = rateUnderlyingAssetsToUsd[0].liquidationFactor;

        // Update variables with elements from index 1 until end of arrays:
        //  - Add USD value of all underlying assets together.
        //  - Keep the lowest risk factor of all underlying assets.
        uint256 length = underlyingAssetsAmounts.length;
        for (uint256 i = 1; i < length; ++i) {
            valueInUsd += underlyingAssetsAmounts[i].mulDivDown(rateUnderlyingAssetsToUsd[i].assetValue, 1e18);

            if (collateralFactor > rateUnderlyingAssetsToUsd[i].collateralFactor) {
                collateralFactor = rateUnderlyingAssetsToUsd[i].collateralFactor;
            }

            if (liquidationFactor > rateUnderlyingAssetsToUsd[i].liquidationFactor) {
                liquidationFactor = rateUnderlyingAssetsToUsd[i].liquidationFactor;
            }
        }

        uint256 riskFactor = riskParams[creditor].riskFactor;

        // Lower risk factors with the protocol wide risk factor.
        liquidationFactor = riskFactor.mulDivDown(liquidationFactor, AssetValuationLib.ONE_4);
        collateralFactor = riskFactor.mulDivDown(collateralFactor, AssetValuationLib.ONE_4);
    }
}
