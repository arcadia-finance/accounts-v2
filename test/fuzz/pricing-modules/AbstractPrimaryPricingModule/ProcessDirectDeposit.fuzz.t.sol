/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processDirectDeposit" of contract "AbstractPrimaryPricingModule".
 */
contract ProcessDirectDeposit_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.processDirectDeposit(asset, 0, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_OverExposure(
        address asset,
        uint96 assetId,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure
    ) public {
        vm.assume(exposure <= type(uint128).max - amount);
        vm.assume(exposure + amount > maxExposure);
        pricingModule.setExposure(asset, assetId, exposure, maxExposure);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APPM_PDD: Exposure not in limits");
        pricingModule.processDirectDeposit(address(asset), assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(
        address asset,
        uint96 assetId,
        uint128 exposure,
        uint128 amount,
        uint128 maxExposure
    ) public {
        vm.assume(exposure <= type(uint128).max - amount);
        vm.assume(exposure + amount <= maxExposure);
        pricingModule.setExposure(asset, assetId, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.processDirectDeposit(address(asset), assetId, amount);

        bytes32 assetKey = bytes32(abi.encodePacked(assetId, asset));
        (, uint128 actualExposure) = pricingModule.exposure(assetKey);
        uint128 expectedExposure = exposure + amount;

        assertEq(actualExposure, expectedExposure);
    }
}
