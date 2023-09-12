/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./AccountV1.fuzz.t.sol";

import { PricingModule_UsdOnly } from "../../../../pricing-modules/AbstractPricingModule_UsdOnly.sol";
import { RiskConstants } from "../../../../utils/RiskConstants.sol";

/**
 * @notice Fuzz tests for the "getLiquidationValue" of contract "AccountV1".
 */
contract GetLiquidationValue_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_getLiquidationValue(uint256 spotValue, uint8 liquidationFactor) public {
        // No overflow of riskModule:
        spotValue = bound(spotValue, 0, type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT);

        // Set Spot Value of assets (value of "stable1" is 1:1 the amount of "stable1" tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, spotValue);

        // Invariant: "liquidationFactor" cannot exceed 100%.
        liquidationFactor = uint8(bound(liquidationFactor, 0, RiskConstants.RISK_VARIABLES_UNIT));

        // Set Liquidation factor of "stable1" for "stable1" to "liquidationFactor".
        PricingModule_UsdOnly.RiskVarInput[] memory riskVarInput = new PricingModule_UsdOnly.RiskVarInput[](1);
        riskVarInput[0].asset = address(mockERC20.stable1);
        riskVarInput[0].baseCurrency = uint8(mainRegistryExtension.assetToBaseCurrency(address(mockERC20.stable1)));
        riskVarInput[0].liquidationFactor = liquidationFactor;
        vm.prank(users.creatorAddress);
        erc20PricingModule.setBatchRiskVariables(riskVarInput);

        uint256 expectedValue = spotValue * liquidationFactor / RiskConstants.RISK_VARIABLES_UNIT;

        uint256 actualValue = accountExtension.getLiquidationValue();

        assertEq(expectedValue, actualValue);
    }
}
