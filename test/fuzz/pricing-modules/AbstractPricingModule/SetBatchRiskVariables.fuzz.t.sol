/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { RiskConstants } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "setBatchRiskVariables" of contract "AbstractPricingModule".
 */
contract SetBatchRiskVariables_AbstractPricingModule_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
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
    function testFuzz_Revert_setBatchRiskVariables_NonRiskManager(
        PricingModule.RiskVarInput[] memory riskVarInputs,
        address unprivilegedAddress_
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_RISK_MANAGER");
        pricingModule.setBatchRiskVariables(riskVarInputs);
        vm.stopPrank();
    }

    function testFuzz_Revert_setBatchRiskVariables_BaseCurrencyNotInLimits(
        PricingModule.RiskVarInput[] memory riskVarInputs,
        uint256 baseCurrencyCounter
    ) public {
        vm.assume(riskVarInputs.length > 0);
        vm.assume(riskVarInputs[0].baseCurrency >= baseCurrencyCounter);

        stdstore.target(address(mainRegistryExtension)).sig(mainRegistryExtension.baseCurrencyCounter.selector)
            .checked_write(baseCurrencyCounter);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("APM_SBRV: BaseCur. not in limits");
        pricingModule.setBatchRiskVariables(riskVarInputs);
        vm.stopPrank();
    }

    function testFuzz_Success_setBatchRiskVariables(PricingModule.RiskVarInput[2] memory riskVarInputs) public {
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
                riskVarInputs[i].asset,
                riskVarInputs[i].baseCurrency,
                riskVarInputs[i].collateralFactor,
                riskVarInputs[i].liquidationFactor
            );
        }
        pricingModule.setBatchRiskVariables(riskVarInputs_);
        vm.stopPrank();

        for (uint256 i; i < riskVarInputs.length; ++i) {
            (uint16 collateralFactor_, uint16 liquidationFactor_) =
                pricingModule.getRiskVariables(riskVarInputs[i].asset, riskVarInputs[i].baseCurrency);
            assertEq(collateralFactor_, riskVarInputs[i].collateralFactor);
            assertEq(liquidationFactor_, riskVarInputs[i].liquidationFactor);
        }
    }
}
