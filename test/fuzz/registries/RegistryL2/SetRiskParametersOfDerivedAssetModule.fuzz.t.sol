/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryL2_Fuzz_Test } from "./_RegistryL2.fuzz.t.sol";

import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "setRiskParametersOfDerivedAM" of contract "RegistryL2".
 */
contract SetRiskParametersOfDerivedAM_RegistryL2_Fuzz_Test is RegistryL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParametersOfDerivedAM_NonRiskManager(
        address unprivilegedAddress_,
        uint112 maxUsdExposureProtocol,
        uint16 riskFactor
    ) public {
        vm.assume(unprivilegedAddress_ != users.riskManager);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.Unauthorized.selector);
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(derivedAM), maxUsdExposureProtocol, riskFactor
        );
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParametersOfDerivedAM(uint112 maxUsdExposureProtocol, uint16 riskFactor) public {
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));

        vm.prank(users.riskManager);
        registry.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(derivedAM), maxUsdExposureProtocol, riskFactor
        );

        (, uint112 actualMaxUsdExposureProtocol, uint16 actualRiskFactor) = derivedAM.riskParams(address(creditorUsd));
        assertEq(actualMaxUsdExposureProtocol, maxUsdExposureProtocol);
        assertEq(actualRiskFactor, riskFactor);
    }
}
