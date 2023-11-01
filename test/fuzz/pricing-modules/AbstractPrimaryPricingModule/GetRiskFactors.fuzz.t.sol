/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "AbstractPrimaryPricingModule".
 */
contract GetRiskFactors_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getRiskFactors(
        address creditor,
        address asset,
        uint96 assetId,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        // And: Risk factors are below max risk factor.
        collateralFactor = uint16(bound(collateralFactor, 0, RiskConstants.RISK_FACTOR_UNIT));
        liquidationFactor = uint16(bound(liquidationFactor, 0, RiskConstants.RISK_FACTOR_UNIT));

        // And: Underlying asset is in primaryPricingModule.
        vm.prank(address(mainRegistryExtension));
        pricingModule.setRiskParameters(creditor, asset, assetId, 0, collateralFactor, liquidationFactor);

        // When: "getRiskFactors" is called.
        (uint16 actualCollateralFactor, uint16 actualLiquidationFactor) =
            pricingModule.getRiskFactors(creditor, asset, assetId);

        // Then: Transaction returns correct risk factors.
        assertEq(actualCollateralFactor, collateralFactor);
        assertEq(actualLiquidationFactor, liquidationFactor);
    }
}
