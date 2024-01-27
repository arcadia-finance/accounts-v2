/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IPrimaryAM {
    /**
     * @notice Sets the risk parameters for an asset for a given creditor.
     * @param creditor The contract address of the creditor.
     * @param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @param maxExposure The maximum exposure of a creditor to the asset.
     * @param collateralFactor The collateral factor of the asset for the creditor, 4 decimals precision.
     * @param liquidationFactor The liquidation factor of the asset for the creditor, 4 decimals precision.
     */
    function setRiskParameters(
        address creditor,
        address asset,
        uint256 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) external;
}
