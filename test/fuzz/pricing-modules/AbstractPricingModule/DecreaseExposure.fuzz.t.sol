/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "decreaseExposure" of contract "AbstractPricingModule".
 */
contract DecreaseExposure_OracleHub_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_decreaseExposure_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint128 id,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.decreaseExposure(asset, id, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_decreaseExposure(
        address asset,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure,
        uint128 id
    ) public {
        vm.assume(maxExposure >= exposure);
        vm.assume(exposure >= amount);
        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.decreaseExposure(asset, id, amount);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure - amount;

        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_decreaseExposure_withAmountGreaterThanExposure(
        address asset,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure,
        uint128 id
    ) public {
        vm.assume(maxExposure >= exposure);
        vm.assume(exposure < amount);
        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.decreaseExposure(asset, id, amount);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));

        assertEq(actualExposure, 0);
    }
}
