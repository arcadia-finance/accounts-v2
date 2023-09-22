/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processIndirectWithdrawal" of contract "AbstractPrimaryPricingModule".
 */
contract ProcessIndirectWithdrawal_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectWithdrawal_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.processIndirectWithdrawal(asset, 0, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectWithdrawal_OverExposure(
        address asset,
        uint128 exposure,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        uint128 maxExposure
    ) public {
        vm.assume(deltaExposureUpperAssetToAsset > 0);
        vm.assume(uint256(deltaExposureUpperAssetToAsset) < type(uint128).max);
        vm.assume(exposure < type(uint128).max);
        vm.assume(exposure + uint256(deltaExposureUpperAssetToAsset) > type(uint128).max);

        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APPM_PIW: Overflow");
        pricingModule.processIndirectWithdrawal(asset, 0, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
        vm.stopPrank();
    }


    function testFuzz_Success_processIndirectWithdrawal_positiveDelta(
        address asset,
        uint128 exposure,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        uint128 maxExposure
    ) public {
        vm.assume(uint256(deltaExposureUpperAssetToAsset) < type(uint128).max);
        vm.assume(exposure <= type(uint128).max - uint256(deltaExposureUpperAssetToAsset));
        vm.assume(exposure + uint256(deltaExposureUpperAssetToAsset) <= maxExposure);

        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.processIndirectWithdrawal(asset, 0, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure + uint128(uint256(deltaExposureUpperAssetToAsset));

        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processIndirectWithdrawal_negativeDeltaWithAbsoluteValueSmallerThanExposure(
        address asset,
        uint128 exposure,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        uint128 maxExposure
    ) public {
        vm.assume(deltaExposureUpperAssetToAsset > type(int128).min);
        vm.assume(deltaExposureUpperAssetToAsset < 0);
        vm.assume(uint256(-deltaExposureUpperAssetToAsset) < exposure);

        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.processIndirectWithdrawal(asset, 0, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));
        uint128 expectedExposure = exposure - uint128(uint256(-deltaExposureUpperAssetToAsset));

        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processIndirectWithdrawal_negativeDeltaGreaterThanExposure(
        address asset,
        uint128 exposure,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        uint128 maxExposure
    ) public {
        vm.assume(deltaExposureUpperAssetToAsset > type(int128).min);
        vm.assume(deltaExposureUpperAssetToAsset < 0);
        vm.assume(uint256(-deltaExposureUpperAssetToAsset) > exposure);

        pricingModule.setExposure(asset, exposure, maxExposure);

        vm.prank(address(mainRegistryExtension));
        pricingModule.processIndirectWithdrawal(asset, 0, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);

        (, uint128 actualExposure) = pricingModule.exposure(address(asset));
        uint128 expectedExposure = 0;

        assertEq(actualExposure, expectedExposure);
    }
}
