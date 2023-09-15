/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { PricingModule } from "../../../../pricing-modules/AbstractPricingModule.sol";
import { RiskConstants } from "../../../../utils/RiskConstants.sol";

/**
 * @notice Fuzz tests for the "getCollateralValue" of contract "AccountV1".
 */
contract GetCollateralValue_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
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
    function testSuccess_getCollateralValue(uint256 spotValue, uint8 collateralFactor) public {
        // No overflow of riskModule:
        spotValue = bound(spotValue, 0, type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT);

        // Set Spot Value of assets (value of "stable1" is 1:1 the amount of "stable1" tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, spotValue);

        // Invariant: "collateralFactor" cannot exceed 100%.
        collateralFactor = uint8(bound(collateralFactor, 0, RiskConstants.RISK_VARIABLES_UNIT));

        // Set Collateral factor of "stable1" for "stable1" to "liquidationFactor".
        PricingModule.RiskVarInput[] memory riskVarInput = new PricingModule.RiskVarInput[](1);
        riskVarInput[0].asset = address(mockERC20.stable1);
        riskVarInput[0].baseCurrency = uint8(mainRegistryExtension.assetToBaseCurrency(address(mockERC20.stable1)));
        riskVarInput[0].collateralFactor = collateralFactor;
        vm.prank(users.creatorAddress);
        erc20PricingModule.setBatchRiskVariables(riskVarInput);

        uint256 expectedValue = spotValue * collateralFactor / RiskConstants.RISK_VARIABLES_UNIT;

        uint256 actualValue = accountExtension.getCollateralValue();

        assertEq(expectedValue, actualValue);
    }
}
