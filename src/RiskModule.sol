/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskConstants } from "./libraries/RiskConstants.sol";

/**
 * @title Risk Module
 * @author Pragma Labs
 * @notice The Risk Module is responsible for calculating the risk weighted values of combinations of assets.
 */
library RiskModule {
    // Struct with risk related information for a certain asset.
    struct AssetValueAndRiskFactors {
        // The value of the asset.
        uint256 assetValue;
        // The collateral factor of the asset, for a given creditor.
        uint256 collateralFactor;
        // The liquidation factor of the asset, for a given creditor.
        uint256 liquidationFactor;
    }

    /*///////////////////////////////////////////////////////////////
                        RISK FACTORS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Calculates the weighted collateral value given a combination of asset values and corresponding collateral factors.
     * @param valuesAndRiskVarPerAsset Array of asset values and corresponding collateral factors.
     * @return collateralValue The collateral value of the given assets.
     */
    function _calculateCollateralValue(AssetValueAndRiskFactors[] memory valuesAndRiskVarPerAsset)
        internal
        pure
        returns (uint256 collateralValue)
    {
        uint256 valuesAndRiskVarPerAssetLength = valuesAndRiskVarPerAsset.length;
        for (uint256 i; i < valuesAndRiskVarPerAssetLength;) {
            collateralValue += valuesAndRiskVarPerAsset[i].assetValue * valuesAndRiskVarPerAsset[i].collateralFactor;
            unchecked {
                ++i;
            }
        }
        collateralValue = collateralValue / RiskConstants.RISK_FACTOR_UNIT;
    }

    /**
     * @notice Calculates the weighted liquidation value given a combination of asset values and corresponding liquidation factors.
     * @param valuesAndRiskVarPerAsset List of asset values and corresponding liquidation factors.
     * @return liquidationValue The liquidation value of the given assets.
     */
    function _calculateLiquidationValue(AssetValueAndRiskFactors[] memory valuesAndRiskVarPerAsset)
        internal
        pure
        returns (uint256 liquidationValue)
    {
        uint256 valuesAndRiskVarPerAssetLength = valuesAndRiskVarPerAsset.length;
        for (uint256 i; i < valuesAndRiskVarPerAssetLength;) {
            liquidationValue += valuesAndRiskVarPerAsset[i].assetValue * valuesAndRiskVarPerAsset[i].liquidationFactor;
            unchecked {
                ++i;
            }
        }
        liquidationValue = liquidationValue / RiskConstants.RISK_FACTOR_UNIT;
    }
}
