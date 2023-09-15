/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPricingModule_Fuzz_Test } from "./_AbstractPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the "processDeposit" of contract "AbstractPricingModule".
 */
contract ProcessDeposit_OracleHub_Fuzz_Test is AbstractPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_processDeposit_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint128 amount,
        address account_
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.processDeposit(account_, asset, 0, amount);
        vm.stopPrank();
    }

    function testRevert_processDeposit_OverExposure(
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
        pricingModule.processDeposit(account_, address(asset), 0, amount);
        vm.stopPrank();
    }

    function testSuccess_processDeposit(
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
        pricingModule.processDeposit(account_, address(asset), 0, amount);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure + amount;

        assertEq(actualExposure, expectedExposure);
    }
}
