/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";

/**
 * @notice Fuzz tests for the function "setRiskParameters" of contract "AbstractDerivedPricingModule".
 */
contract SetRiskParameters_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParameters_NonMainRegistry(
        address unprivilegedAddress_,
        address creditor,
        uint128 maxExposureInUsd,
        uint16 riskFactor
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        derivedPricingModule.setRiskParameters(creditor, maxExposureInUsd, riskFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_RiskFactorNotInLimits(
        address creditor,
        uint128 maxExposureInUsd,
        uint16 riskFactor
    ) public {
        riskFactor = uint16(bound(riskFactor, RiskConstants.RISK_FACTOR_UNIT + 1, type(uint16).max));

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("ADPM_SRP: Risk Fact not in limits");
        derivedPricingModule.setRiskParameters(creditor, maxExposureInUsd, riskFactor);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParameters(address creditor, uint128 maxExposureInUsd, uint16 riskFactor) public {
        riskFactor = uint16(bound(riskFactor, 0, RiskConstants.RISK_FACTOR_UNIT));

        vm.prank(address(mainRegistryExtension));
        derivedPricingModule.setRiskParameters(creditor, maxExposureInUsd, riskFactor);

        (, uint128 actualMaxExposureInUsd, uint16 actualRiskFactor) = derivedPricingModule.riskParams(creditor);
        assertEq(actualMaxExposureInUsd, maxExposureInUsd);
        assertEq(actualRiskFactor, riskFactor);
    }
}
