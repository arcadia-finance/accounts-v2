/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { PricingModule, RiskConstants } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "_setRiskVariablesForAsset" of contract "AbstractPricingModule".
 */
contract SetRiskVariablesForAsset_AbstractPricingModule_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskVariablesForAsset_BaseCurrencyNotInLimits(
        address asset,
        PricingModule.RiskVarInput[] memory riskVarInputs,
        uint256 baseCurrencyCounter
    ) public {
        vm.assume(riskVarInputs.length > 0);
        vm.assume(riskVarInputs[0].baseCurrency >= baseCurrencyCounter);

        stdstore.target(address(mainRegistryExtension)).sig(mainRegistryExtension.baseCurrencyCounter.selector)
            .checked_write(baseCurrencyCounter);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("APM_SRVFA: BaseCur not in limits");
        pricingModule.setRiskVariablesForAsset(asset, riskVarInputs);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskVariablesForAsset(
        address asset,
        PricingModule.RiskVarInput[2] memory riskVarInputs
    ) public {
        vm.assume(riskVarInputs[0].baseCurrency != riskVarInputs[1].baseCurrency);

        stdstore.target(address(mainRegistryExtension)).sig(mainRegistryExtension.baseCurrencyCounter.selector)
            .checked_write(type(uint256).max);

        for (uint256 i; i < riskVarInputs.length; ++i) {
            riskVarInputs_.push(riskVarInputs[i]);
            vm.assume(riskVarInputs[i].collateralFactor <= RiskConstants.MAX_COLLATERAL_FACTOR);
            vm.assume(riskVarInputs[i].liquidationFactor <= RiskConstants.MAX_LIQUIDATION_FACTOR);
        }

        vm.startPrank(users.creatorAddress);
        for (uint256 i; i < riskVarInputs.length; ++i) {
            vm.expectEmit(true, true, true, true);
            emit RiskVariablesSet(
                asset,
                riskVarInputs[i].baseCurrency,
                riskVarInputs[i].collateralFactor,
                riskVarInputs[i].liquidationFactor
            );
        }
        pricingModule.setRiskVariablesForAsset(asset, riskVarInputs_);
        vm.stopPrank();

        for (uint256 i; i < riskVarInputs.length; ++i) {
            (uint16 collateralFactor_, uint16 liquidationFactor_) =
                pricingModule.getRiskVariables(asset, riskVarInputs[i].baseCurrency);
            assertEq(collateralFactor_, riskVarInputs[i].collateralFactor);
            assertEq(liquidationFactor_, riskVarInputs[i].liquidationFactor);
        }
    }
}
