/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";

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
    function testFuzz_Success_getCollateralValue(uint128 spotValue, uint8 collateralFactor) public {
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

        uint256 expectedValue = uint256(spotValue) * collateralFactor / RiskConstants.RISK_VARIABLES_UNIT;

        uint256 actualValue = accountExtension.getCollateralValue();

        assertEq(expectedValue, actualValue);
    }
}
