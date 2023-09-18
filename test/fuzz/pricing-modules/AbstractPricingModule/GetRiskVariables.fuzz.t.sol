/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "getRiskVariables" of contract "AbstractPricingModule".
 */
contract GetRiskVariables_AbstractPricingModule_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
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
    function testFuzz_Success_getRiskVariables_RiskVariablesAreNotSet(address asset, uint256 baseCurrency) public {
        (uint16 actualCollateralFactor, uint16 actualLiquidationThreshold) =
            pricingModule.getRiskVariables(asset, baseCurrency);

        assertEq(actualCollateralFactor, 0);
        assertEq(actualLiquidationThreshold, 0);
    }

    function testFuzz_Success_getRiskVariables_RiskVariablesAreSet(
        address asset,
        uint256 baseCurrency,
        uint16 collateralFactor_,
        uint16 liquidationFactor_
    ) public {
        uint256 slot = stdstore.target(address(pricingModule)).sig(pricingModule.assetRiskVars.selector).with_key(asset)
            .with_key(baseCurrency).find();
        bytes32 loc = bytes32(slot);
        bytes32 value = bytes32(abi.encodePacked(liquidationFactor_, collateralFactor_));
        value = value >> 224;
        vm.store(address(pricingModule), loc, value);

        (uint16 actualCollateralFactor, uint16 actualLiquidationThreshold) =
            pricingModule.getRiskVariables(asset, baseCurrency);

        assertEq(actualCollateralFactor, collateralFactor_);
        assertEq(actualLiquidationThreshold, liquidationFactor_);
    }
}
