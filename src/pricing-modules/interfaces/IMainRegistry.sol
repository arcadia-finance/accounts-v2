/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

import { IPricingModule } from "../../interfaces/IPricingModule.sol";
import { RiskModule } from "../../RiskModule.sol";

interface IMainRegistry {
    //todo
    function getPricingModuleOfAsset(address asset) external view returns (address pricingModule);

    /**
     * @notice Returns the number of baseCurrencies.
     * @return Counter for the number of baseCurrencies in use.
     */
    function baseCurrencyCounter() external view returns (uint256);

    /**
     * @notice Adds a new asset to the Main Registry.
     * @param asset The contract address of the asset.
     * @param assetType Identifier for the type of the asset:
     * 0 = ERC20.
     * 1 = ERC721.
     * 2 = ERC1155.
     */
    function addAsset(address asset, uint256 assetType) external;

    /**
     * @notice This function is called by pricing modules of non-primary assets in order to increase the exposure of the underlying asset.
     * @param underlyingAsset The underlying asset of a non-primary asset.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function getUsdValueExposureToUnderlyingAssetAfterDeposit(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external returns (uint256 usdExposureAssetToUnderlyingAsset);

    /**
     * @notice This function is called by pricing modules of non-primary assets in order to decrease the exposure of the underlying asset.
     * @param underlyingAsset The underlying asset of a non-primary asset.
     * @param underlyingAssetId The underlying asset ID.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the upper asset (asset in previous pricing module called) to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the upper asset to the underlying asset since last update.
     */
    function getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external returns (uint256 usdExposureAssetToUnderlyingAsset);

    /**
     * @notice Calculates the usd value of an asset.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param assetAmount The amount of assets.
     * @return usdValue The value of the asset denominated in USD, with 18 Decimals precision.
     */
    function getUsdValue(address creditor, address asset, uint256 assetId, uint256 assetAmount)
        external
        view
        returns (uint256);

    function getUsdValues(
        address creditor,
        address[] calldata assets,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (RiskModule.AssetValueAndRiskVariables[] memory valuesAndRiskVarPerAsset);

    function isAllowed(address asset, uint256 assetId) external view returns (bool);
}
