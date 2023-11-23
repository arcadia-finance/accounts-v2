/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskModule_Fuzz_Test } from "./_RiskModule.fuzz.t.sol";

import { RiskModule } from "../../../src/RiskModule.sol";
import { RiskModule } from "../../../src/RiskModule.sol";

/**
 * @notice Fuzz tests for the function "calculateLiquidationValue" of contract "RiskModule".
 */
contract CalculateLiquidationValue_RiskModule_Fuzz_Test is RiskModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RiskModule_Fuzz_Test.setUp();
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
        RiskModule.AssetValueAndRiskFactors[] memory values = new RiskModule.AssetValueAndRiskFactors[](2);
        values[0].assetValue = firstValue;
        values[1].assetValue = secondValue;

        // And: Liquidation factors are within allowed ranges
        vm.assume(firstLiqFactor <= RiskModule.ONE_4);
        vm.assume(secondLiqFactor <= RiskModule.ONE_4);

        values[0].liquidationFactor = firstLiqFactor;
        values[1].liquidationFactor = secondLiqFactor;

        // When: The Liquidation factor is calculated with given values
        uint256 liquidationValue = riskModule.calculateLiquidationValue(values);

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
