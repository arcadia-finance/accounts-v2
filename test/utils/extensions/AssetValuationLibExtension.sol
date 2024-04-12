/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";

contract AssetValuationLibExtension {
    function calculateCollateralValue(AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        external
        pure
        returns (uint256 collateralValue)
    {
        collateralValue = AssetValuationLib._calculateCollateralValue(valuesAndRiskFactors);
    }

    function calculateLiquidationValue(AssetValueAndRiskFactors[] memory valuesAndRiskFactors)
        external
        pure
        returns (uint256 liquidationValue)
    {
        liquidationValue = AssetValuationLib._calculateLiquidationValue(valuesAndRiskFactors);
    }
}
