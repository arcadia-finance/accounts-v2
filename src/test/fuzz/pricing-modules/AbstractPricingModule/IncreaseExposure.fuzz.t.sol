/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./AbstractPricingModule.fuzz.t.sol";

import { PricingModule_UsdOnly } from "../../../../pricing-modules/AbstractPricingModule_UsdOnly.sol";

/**
 * @notice Fuzz tests for the "increaseExposure" of contract "AbstractPricingModule".
 */
contract IncreaseExposure_OracleHub_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_increaseExposure_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint128 amount,
        address account_
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.increaseExposure(asset, 0, amount);
        vm.stopPrank();
    }

    function testRevert_increaseExposure_OverExposure(
        address asset,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure,
        address account_
    ) public {
        vm.assume(exposure <= type(uint128).max - amount);
        vm.assume(exposure + amount > maxExposure);
        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APM_PD: Exposure not in limits");
        pricingModule.increaseExposure(address(asset), 0, amount);
        vm.stopPrank();
    }

    function testSuccess_increaseExposure(
        address asset,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure,
        address account_
    ) public {
        vm.assume(exposure <= type(uint128).max - amount);
        vm.assume(exposure + amount <= maxExposure);
        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.increaseExposure(address(asset), 0, amount);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure + amount;

        assertEq(actualExposure, expectedExposure);
    }
}
