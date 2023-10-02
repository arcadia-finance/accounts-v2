/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processDirectWithdrawal" of contract "AbstractPrimaryPricingModule".
 */
contract ProcessDirectWithdrawal_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectWithdrawal_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.processDirectWithdrawal(asset, 0, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectWithdrawal(
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
        pricingModule.processDirectWithdrawal(asset, id, amount);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure - amount;

        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processDirectWithdrawal_withAmountGreaterThanExposure(
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
        pricingModule.processDirectWithdrawal(asset, id, amount);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));

        assertEq(actualExposure, 0);
    }
}
