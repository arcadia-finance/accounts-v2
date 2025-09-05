/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";
import { DerivedAMMock } from "../../../utils/mocks/asset-modules/DerivedAMMock.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setRiskParametersOfDerivedAM" of contract "UniswapV4HooksRegistry".
 */
contract SetRiskParametersOfDerivedAM_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    DerivedAMMock internal derivedAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();

        vm.startPrank(users.owner);
        derivedAM = new DerivedAMMock(address(registry), 0);
        registry.addAssetModule(address(derivedAM));
        vm.stopPrank();
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
