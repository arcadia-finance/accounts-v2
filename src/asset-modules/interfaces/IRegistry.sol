/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";

interface IRegistry {
    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) external view returns (bool);

    /**
     * @notice Adds a new asset to the Registry.
     * @param asset The contract address of the asset.
     */
    function addAsset(address asset) external;

    /**
     * @notice Verifies whether a sequence of oracles complies with a predetermined set of criteria.
     * @param oracleSequence The sequence of the oracles to price a certain asset in USD,
     * packed in a single bytes32 object.
     * @return A boolean, indicating if the sequence complies with the set of criteria.
     */
    function checkOracleSequence(bytes32 oracleSequence) external view returns (bool);

    /**
     * @notice Returns the risk factors per asset for a creditor.
     * @param creditor The contract address of the creditor.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @return collateralFactors Array of the collateral factors of the assets for the creditor, 4 decimals precision.
     * @return liquidationFactors Array of the liquidation factors of the assets for the creditor, 4 decimals precision.
     */
    function getRiskFactors(address creditor, address[] calldata assetAddresses, uint256[] calldata assetIds)
        external
        view
        returns (uint16[] memory, uint16[] memory);

    /**
     * @notice This function is called by pricing modules of non-primary assets in order to update the exposure of an underlying asset after a deposit.
     * @param creditor The contract address of the creditor.
     * @param underlyingAsset The underlying asset.
     * @param underlyingAssetId The underlying asset ID.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the asset to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the asset to the underlying asset since the last interaction.
     * @return recursiveCalls The number of calls done to different asset modules to process the deposit/withdrawal of the asset.
     * @return usdExposureAssetToUnderlyingAsset The Usd value of the exposure of the asset to the underlying asset, 18 decimals precision.
     */
    function getUsdValueExposureToUnderlyingAssetAfterDeposit(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external returns (uint256, uint256);

    /**
     * @notice This function is called by pricing modules of non-primary assets in order to update the exposure of an underlying asset after a withdrawal.
     * @param creditor The contract address of the creditor.
     * @param underlyingAsset The underlying asset.
     * @param underlyingAssetId The underlying asset ID.
     * @param exposureAssetToUnderlyingAsset The amount of exposure of the asset to the underlying asset.
     * @param deltaExposureAssetToUnderlyingAsset The increase or decrease in exposure of the asset to the underlying asset since the last interaction.
     * @return usdExposureAssetToUnderlyingAsset The Usd value of the exposure of the asset to the underlying asset, 18 decimals precision.
     */
    function getUsdValueExposureToUnderlyingAssetAfterWithdrawal(
        address creditor,
        address underlyingAsset,
        uint256 underlyingAssetId,
        uint256 exposureAssetToUnderlyingAsset,
        int256 deltaExposureAssetToUnderlyingAsset
    ) external returns (uint256 usdExposureAssetToUnderlyingAsset);

    /**
     * @notice Returns the rate of a certain asset in USD.
     * @param oracleSequence The sequence of the oracles to price a certain asset in USD,
     * packed in a single bytes32 object.
     * @return rate The USD rate of an asset with 18 decimals precision.
     */
    function getRateInUsd(bytes32 oracleSequence) external view returns (uint256);

    /**
     * @notice Calculates the USD values of underlying assets.
     * @param creditor The contract address of the creditor.
     * @param assets Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @return valuesAndRiskFactors The value of the asset denominated in USD, with 18 Decimals precision.
     */
    function getValuesInUsdRecursive(
        address creditor,
        address[] calldata assets,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts
    ) external view returns (AssetValueAndRiskFactors[] memory valuesAndRiskFactors);
}
