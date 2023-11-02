/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { RiskModule_Fuzz_Test } from "./_RiskModule.fuzz.t.sol";

import { RiskModule } from "../../../src/RiskModule.sol";
import { RiskConstants } from "../../../src/libraries/RiskConstants.sol";

/**
 * @notice Fuzz tests for the function "calculateCollateralFactor" of contract "RiskModule".
 */
contract CalculateCollateralFactor_RiskModule_Fuzz_Test is RiskModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override { }

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
        RiskModule.AssetValueAndRiskVariables[] memory values = new RiskModule.AssetValueAndRiskVariables[](2);
        values[0].valueInBaseCurrency = firstValue;
        values[1].valueInBaseCurrency = secondValue;

        // And: collateral factors are within allowed ranges
        vm.assume(firstCollFactor <= RiskConstants.RISK_FACTOR_UNIT);
        vm.assume(secondCollFactor <= RiskConstants.RISK_FACTOR_UNIT);

        values[0].collateralFactor = firstCollFactor;
        values[1].collateralFactor = secondCollFactor;

        // When: The collateral factor is calculated with given values
        uint256 collateralValue = RiskModule.calculateCollateralValue(values);

        // Then: It should be equal to calculated collateral factor
        uint256 calcCollateralValue;
        for (uint256 i; i < values.length;) {
            calcCollateralValue += values[i].valueInBaseCurrency * values[i].collateralFactor;
            unchecked {
                ++i;
            }
        }

        calcCollateralValue = calcCollateralValue / 100;
        assertEq(collateralValue, calcCollateralValue);
    }
}
