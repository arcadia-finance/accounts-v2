/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./AbstractPricingModule.fuzz.t.sol";

import { PricingModule_UsdOnly } from "../../../../pricing-modules/AbstractPricingModule_UsdOnly.sol";

/**
 * @notice Fuzz tests for the "processWithdrawal" of contract "AbstractPricingModule".
 */
contract ProcessWithdrawal_OracleHub_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_processWithdrawal_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint128 id,
        uint128 amount,
        address account_
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.processWithdrawal(account_, asset, id, amount);
        vm.stopPrank();
    }

    function testSuccess_processWithdrawal(
        address asset,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure,
        uint128 id,
        address account_
    ) public {
        vm.assume(maxExposure >= exposure);
        vm.assume(exposure >= amount);
        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.processWithdrawal(account_, asset, id, amount);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure - amount;

        assertEq(actualExposure, expectedExposure);
    }

    function testSuccess_processWithdrawal_withAmountGreaterThanExposure(
        address asset,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure,
        uint128 id,
        address account_
    ) public {
        vm.assume(maxExposure >= exposure);
        vm.assume(exposure < amount);
        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.processWithdrawal(account_, asset, id, amount);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));

        assertEq(actualExposure, 0);
    }
}
