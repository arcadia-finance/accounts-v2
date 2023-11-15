/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedAssetModule_Fuzz_Test } from "./_AbstractDerivedAssetModule.fuzz.t.sol";

import { RiskConstants } from "../../../../src/libraries/RiskConstants.sol";

/**
 * @notice Fuzz tests for the function "setRiskParameters" of contract "AbstractDerivedAssetModule".
 */
contract SetRiskParameters_AbstractDerivedAssetModule_Fuzz_Test is AbstractDerivedAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParameters_NonRegistry(
        address unprivilegedAddress_,
        address creditor,
        uint128 maxExposureInUsd,
        uint16 riskFactor
    ) public {
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("AAM: ONLY_REGISTRY");
        derivedAssetModule.setRiskParameters(creditor, maxExposureInUsd, riskFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_RiskFactorNotInLimits(
        address creditor,
        uint128 maxExposureInUsd,
        uint16 riskFactor
    ) public {
        riskFactor = uint16(bound(riskFactor, RiskConstants.RISK_FACTOR_UNIT + 1, type(uint16).max));

        vm.startPrank(address(registryExtension));
        vm.expectRevert("ADAM_SRP: Risk Fact not in limits");
        derivedAssetModule.setRiskParameters(creditor, maxExposureInUsd, riskFactor);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParameters(address creditor, uint128 maxExposureInUsd, uint16 riskFactor) public {
        riskFactor = uint16(bound(riskFactor, 0, RiskConstants.RISK_FACTOR_UNIT));

        vm.prank(address(registryExtension));
        derivedAssetModule.setRiskParameters(creditor, maxExposureInUsd, riskFactor);

        (, uint128 actualMaxExposureInUsd, uint16 actualRiskFactor) = derivedAssetModule.riskParams(creditor);
        assertEq(actualMaxExposureInUsd, maxExposureInUsd);
        assertEq(actualRiskFactor, riskFactor);
    }
}
