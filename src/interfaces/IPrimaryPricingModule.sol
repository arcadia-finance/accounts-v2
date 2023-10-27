/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IPrimaryPricingModule {
    /**
     * @notice Sets the risk parameters for an asset for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param maxExposure The maximum exposure of a creditor to the asset.
     * @param collateralFactor The collateral factor of the asset for the creditor, 2 decimals precision.
     * @param liquidationFactor The liquidation factor of the asset for the creditor, 2 decimals precision.
     */
    function setRiskParameters(
        address creditor,
        address asset,
        uint256 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) external;
}
