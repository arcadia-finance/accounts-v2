/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "setRiskParametersOfDerivedAM" of contract "Registry".
 */
contract SetRiskParametersOfDerivedAM_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
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
        registryExtension.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(derivedAM), maxUsdExposureProtocol, riskFactor
        );
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParametersOfDerivedAM(uint112 maxUsdExposureProtocol, uint16 riskFactor) public {
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfDerivedAM(
            address(creditorUsd), address(derivedAM), maxUsdExposureProtocol, riskFactor
        );

        (, uint112 actualMaxUsdExposureProtocol, uint16 actualRiskFactor) = derivedAM.riskParams(address(creditorUsd));
        assertEq(actualMaxUsdExposureProtocol, maxUsdExposureProtocol);
        assertEq(actualRiskFactor, riskFactor);
    }
}
