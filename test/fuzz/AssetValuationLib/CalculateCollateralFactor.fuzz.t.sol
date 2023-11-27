/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValuationLib_Fuzz_Test } from "./_AssetValuationLib.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "calculateCollateralFactor" of contract "AssetValuationLib".
 */
contract CalculateCollateralFactor_AssetValuationLib_Fuzz_Test is AssetValuationLib_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AssetValuationLib_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_calculateCollateralFactor(
        uint128 firstValue,
        uint128 secondValue,
        uint16 firstCollFactor,
        uint16 secondCollFactor
    ) public {
        // Given: 2 Assets with value bigger than zero
        // Values are uint128 to prevent overflow in multiplication
        AssetValueAndRiskFactors[] memory values = new AssetValueAndRiskFactors[](2);
        values[0].assetValue = firstValue;
        values[1].assetValue = secondValue;

        // And: collateral factors are within allowed ranges
        vm.assume(firstCollFactor <= AssetValuationLib.ONE_4);
        vm.assume(secondCollFactor <= AssetValuationLib.ONE_4);

        values[0].collateralFactor = firstCollFactor;
        values[1].collateralFactor = secondCollFactor;

        // When: The collateral factor is calculated with given values
        uint256 collateralValue = assetValuationLib.calculateCollateralValue(values);

        // Then: It should be equal to calculated collateral factor
        uint256 calcCollateralValue;
        for (uint256 i; i < values.length;) {
            calcCollateralValue += values[i].assetValue * values[i].collateralFactor;
            unchecked {
                ++i;
            }
        }

        calcCollateralValue = calcCollateralValue / 10_000;
        assertEq(collateralValue, calcCollateralValue);
    }
}
