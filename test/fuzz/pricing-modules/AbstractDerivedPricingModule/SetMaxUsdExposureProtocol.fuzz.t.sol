/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule_New.sol";

/**
 * @notice Fuzz tests for the "setMaxUsdExposureProtocol" of contract "AbstractDerivedPricingModule".
 */
contract SetMaxExposure_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_setMaxUsdExposureProtocol(uint256 maxExposureInUsd) public {
        vm.prank(derivedPricingModule.riskManager());
        derivedPricingModule.setMaxUsdExposureProtocol(maxExposureInUsd);

        assert(derivedPricingModule.maxUsdExposureProtocol() == maxExposureInUsd);
    }
}
