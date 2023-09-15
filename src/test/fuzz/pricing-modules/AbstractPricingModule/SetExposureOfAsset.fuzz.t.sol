/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "setExposureOfAsset" of contract "AbstractPricingModule".
 */
contract SetExposureOfAsset_OracleHub_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setExposureOfAsset_NonRiskManager(
        address unprivilegedAddress_,
        address asset,
        uint128 maxExposure
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_RISK_MANAGER");
        pricingModule.setExposureOfAsset(asset, maxExposure);
        vm.stopPrank();
    }

    function testFuzz_Success_setExposureOfAsset(address asset, uint128 maxExposure) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit MaxExposureSet(asset, maxExposure);
        pricingModule.setExposureOfAsset(asset, maxExposure);
        vm.stopPrank();

        (uint128 actualMaxExposure,) = pricingModule.exposure(asset);
        assertEq(actualMaxExposure, maxExposure);
    }
}
