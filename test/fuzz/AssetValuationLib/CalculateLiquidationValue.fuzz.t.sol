/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValuationLib_Fuzz_Test } from "./_AssetValuationLib.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "calculateLiquidationValue" of contract "AssetValuationLib".
 */
contract CalculateLiquidationValue_AssetValuationLib_Fuzz_Test is AssetValuationLib_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AssetValuationLib_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_calculateLiquidationValue(
        uint128 firstValue,
        uint128 secondValue,
        uint16 firstLiqFactor,
        uint16 secondLiqFactor
    ) public {
        // Given: 2 Assets with value bigger than zero
        // Values are uint128 to prevent overflow in multiplication
        AssetValueAndRiskFactors[] memory values = new AssetValueAndRiskFactors[](2);
        values[0].assetValue = firstValue;
        values[1].assetValue = secondValue;

        // And: Liquidation factors are within allowed ranges
        vm.assume(firstLiqFactor <= AssetValuationLib.ONE_4);
        vm.assume(secondLiqFactor <= AssetValuationLib.ONE_4);

        values[0].liquidationFactor = firstLiqFactor;
        values[1].liquidationFactor = secondLiqFactor;

        // When: The Liquidation factor is calculated with given values
        uint256 liquidationValue = assetValuationLib.calculateLiquidationValue(values);

        // Then: It should be equal to calculated Liquidation factor
        uint256 calcLiquidationValue;
        for (uint256 i; i < values.length;) {
            calcLiquidationValue += values[i].assetValue * values[i].liquidationFactor;
            unchecked {
                ++i;
            }
        }

        calcLiquidationValue = calcLiquidationValue / 10_000;
        assertEq(liquidationValue, calcLiquidationValue);
    }
}
