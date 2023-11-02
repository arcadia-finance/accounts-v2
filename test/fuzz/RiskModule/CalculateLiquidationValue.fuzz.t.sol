/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskModule_Fuzz_Test } from "./_RiskModule.fuzz.t.sol";

import { RiskModule } from "../../../src/RiskModule.sol";
import { RiskConstants } from "../../../src/libraries/RiskConstants.sol";

/**
 * @notice Fuzz tests for the function "calculateLiquidationValue" of contract "RiskModule".
 */
contract CalculateLiquidationValue_RiskModule_Fuzz_Test is RiskModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

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
        RiskModule.AssetValueAndRiskVariables[] memory values = new RiskModule.AssetValueAndRiskVariables[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // And: Liquidation factors are within allowed ranges
        vm.assume(firstLiqFactor <= RiskConstants.RISK_FACTOR_UNIT);
        vm.assume(secondLiqFactor <= RiskConstants.RISK_FACTOR_UNIT);

        values[0].liquidationFactor = firstLiqFactor;
        values[1].liquidationFactor = secondLiqFactor;

        // When: The Liquidation factor is calculated with given values
        uint256 liquidationValue = RiskModule.calculateLiquidationValue(values);

        // Then: It should be equal to calculated Liquidation factor
        uint256 calcLiquidationValue;
        for (uint256 i; i < values.length;) {
            calcLiquidationValue += values[i].valueInBaseCurrency * values[i].liquidationFactor;
            unchecked {
                ++i;
            }
        }

        calcLiquidationValue = calcLiquidationValue / 100;
        assertEq(liquidationValue, calcLiquidationValue);
    }
}
