/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./AbstractPricingModule.fuzz.t.sol";

import { PricingModule, RiskConstants } from "../../../../pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "_setRiskVariables" of contract "AbstractPricingModule".
 */
contract SetRiskVariables_AbstractPricingModule_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_setRiskVariables_CollateralFactorOutOfLimits(
        address asset,
        uint256 baseCurrency,
        PricingModule.RiskVars memory riskVars_
    ) public {
        vm.assume(riskVars_.collateralFactor > RiskConstants.MAX_COLLATERAL_FACTOR);

        vm.expectRevert("APM_SRV: Coll.Fact not in limits");
        pricingModule.setRiskVariables(asset, baseCurrency, riskVars_);

        (uint16 collateralFactor_, uint16 liquidationFactor_) = pricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor_, 0);
        assertEq(liquidationFactor_, 0);
    }

    function testRevert_setRiskVariables_LiquidationTreshholdOutOfLimits(
        address asset,
        uint256 baseCurrency,
        PricingModule.RiskVars memory riskVars_
    ) public {
        vm.assume(riskVars_.collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);

        vm.assume(riskVars_.liquidationFactor > RiskConstants.MAX_LIQUIDATION_FACTOR);

        vm.expectRevert("APM_SRV: Liq.Fact not in limits");
        pricingModule.setRiskVariables(asset, baseCurrency, riskVars_);

        (uint16 collateralFactor_, uint16 liquidationFactor_) = pricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor_, 0);
        assertEq(liquidationFactor_, 0);
    }

    function testSuccess_setRiskVariables(address asset, uint8 baseCurrency, PricingModule.RiskVars memory riskVars_)
        public
    {
        vm.assume(riskVars_.collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);
        vm.assume(riskVars_.liquidationFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR);

        vm.expectEmit(true, true, true, true);
        emit RiskVariablesSet(asset, baseCurrency, riskVars_.collateralFactor, riskVars_.liquidationFactor);
        pricingModule.setRiskVariables(asset, baseCurrency, riskVars_);

        (uint16 collateralFactor_, uint16 liquidationFactor_) = pricingModule.getRiskVariables(asset, baseCurrency);
        assertEq(collateralFactor_, riskVars_.collateralFactor);
        assertEq(liquidationFactor_, riskVars_.liquidationFactor);
    }
}
