/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule_New.sol";

/**
 * @notice Fuzz tests for the "processIndirectDeposit" of contract "AbstractDerivedPricingModule".
 * @notice Tests performed here will validate the recursion flow of derived pricing modules.
 * Testing for conversion rates and getValue() will be done in pricing modules testing separately.
 */
contract ProcessIndirectDeposit_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_processIndirectDeposit_positiveDelta(
        address asset,
        address underlyingAsset,
        uint128 exposureAssetLast,
        int256 deltaExposureUpperAssetToAsset,
        uint256 id,
        uint256 exposureUpperAssetToAsset
    ) public {
        vm.assume(deltaExposureUpperAssetToAsset > 0);
        vm.assume(uint256(deltaExposureUpperAssetToAsset) < type(uint128).max - exposureAssetLast);
        vm.assume(exposureUpperAssetToAsset < type(uint128).max);

        // Set exposure of underlying (primary) asset to max
        primaryPricingModule.setExposure(underlyingAsset, exposureAssetLast, type(uint128).max);
        // Set usd exposure of protocol to max
        derivedPricingModule.setUsdExposureProtocol(type(uint256).max, exposureAssetLast);

        address[] memory underlyingAssets = new address[](1);
        underlyingAssets[0] = underlyingAsset;
        uint128[] memory exposureAssetToUnderlyingAssetsLast = new uint128[](1);
        exposureAssetToUnderlyingAssetsLast[0] = exposureAssetLast;

        // Add asset to pricing module
        derivedPricingModule.addAsset(asset, underlyingAssets);
        // Set asset info
        derivedPricingModule.setAssetInformation(
            asset, exposureAssetLast, exposureAssetLast, exposureAssetToUnderlyingAssetsLast
        );

        // Set the pricing module for the underlying asset in MainRegistry
        mainRegistryExtension_New.setPricingModuleForAsset(underlyingAsset, address(primaryPricingModule));

        // Pre check
        (, uint128 PreExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
        assert(PreExposureUnderlyingAsset == exposureAssetLast);
        assert(derivedPricingModule.usdExposureProtocol() == exposureAssetLast);

        vm.prank(address(mainRegistryExtension_New));
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // After check, exposures should have increased
        (, uint128 AfterExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
        assert(AfterExposureUnderlyingAsset == exposureAssetLast + uint256(deltaExposureUpperAssetToAsset));
        //assert(
        //    derivedPricingModule.usdExposureProtocol() == exposureAssetLast + uint256(deltaExposureUpperAssetToAsset)
        //);
        assert(PRIMARY_FLAG == false);
        //assert(usdValueExposureUpperAssetToAsset == exposureUpperAssetToAsset);
    }

    function testFuzz_Success_processIndirectDeposit_negativeDeltaLessThanPreviousExposure(
        address asset,
        address underlyingAsset,
        uint128 exposureAssetLast,
        int256 deltaExposureUpperAssetToAsset,
        uint256 id,
        uint256 exposureUpperAssetToAsset
    ) public {
        vm.assume(deltaExposureUpperAssetToAsset < 0);
        vm.assume(deltaExposureUpperAssetToAsset > type(int128).min);
        vm.assume(uint256(-deltaExposureUpperAssetToAsset) < exposureAssetLast);
        vm.assume(exposureUpperAssetToAsset < type(uint128).max);

        // Set exposure of underlying (primary) asset to max
        primaryPricingModule.setExposure(underlyingAsset, exposureAssetLast, type(uint128).max);
        // Set usd exposure of protocol to max
        derivedPricingModule.setUsdExposureProtocol(type(uint256).max, exposureAssetLast);

        address[] memory underlyingAssets = new address[](1);
        underlyingAssets[0] = underlyingAsset;
        uint128[] memory exposureAssetToUnderlyingAssetsLast = new uint128[](1);
        exposureAssetToUnderlyingAssetsLast[0] = exposureAssetLast;

        // Add asset to pricing module
        derivedPricingModule.addAsset(asset, underlyingAssets);
        // Set asset info
        derivedPricingModule.setAssetInformation(
            asset, exposureAssetLast, exposureAssetLast, exposureAssetToUnderlyingAssetsLast
        );

        // Set the pricing module for the underlying asset in MainRegistry
        mainRegistryExtension_New.setPricingModuleForAsset(underlyingAsset, address(primaryPricingModule));

        // Pre check
        (, uint128 PreExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
        assert(PreExposureUnderlyingAsset == exposureAssetLast);
        assert(derivedPricingModule.usdExposureProtocol() == exposureAssetLast);

        vm.prank(address(mainRegistryExtension_New));
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // After check, exposures should have increased
        (, uint128 AfterExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
        assert(AfterExposureUnderlyingAsset == exposureAssetLast - uint256(-deltaExposureUpperAssetToAsset));
        //assert(
        //    derivedPricingModule.usdExposureProtocol() == exposureAssetLast - uint256(-deltaExposureUpperAssetToAsset)
        //);
        assert(PRIMARY_FLAG == false);
        //assert(usdValueExposureUpperAssetToAsset == exposureUpperAssetToAsset);
    }

    function testFuzz_Success_processIndirectDeposit_negativeDeltaGreaterThanPreviousExposure(
        address asset,
        address underlyingAsset,
        uint128 exposureAssetLast,
        int256 deltaExposureUpperAssetToAsset,
        uint256 id,
        uint256 exposureUpperAssetToAsset
    ) public {
        vm.assume(deltaExposureUpperAssetToAsset < 0);
        vm.assume(deltaExposureUpperAssetToAsset > type(int128).min);
        vm.assume(uint256(-deltaExposureUpperAssetToAsset) > exposureAssetLast);
        vm.assume(exposureUpperAssetToAsset < type(uint128).max);

        // Set exposure of underlying (primary) asset to max
        primaryPricingModule.setExposure(underlyingAsset, exposureAssetLast, type(uint128).max);
        // Set usd exposure of protocol to max
        derivedPricingModule.setUsdExposureProtocol(type(uint256).max, exposureAssetLast);

        address[] memory underlyingAssets = new address[](1);
        underlyingAssets[0] = underlyingAsset;
        uint128[] memory exposureAssetToUnderlyingAssetsLast = new uint128[](1);
        exposureAssetToUnderlyingAssetsLast[0] = exposureAssetLast;

        // Add asset to pricing module
        derivedPricingModule.addAsset(asset, underlyingAssets);
        // Set asset info
        derivedPricingModule.setAssetInformation(
            asset, exposureAssetLast, exposureAssetLast, exposureAssetToUnderlyingAssetsLast
        );

        // Set the pricing module for the underlying asset in MainRegistry
        mainRegistryExtension_New.setPricingModuleForAsset(underlyingAsset, address(primaryPricingModule));

        // Pre check
        (, uint128 PreExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
        assert(PreExposureUnderlyingAsset == exposureAssetLast);
        assert(derivedPricingModule.usdExposureProtocol() == exposureAssetLast);

        vm.prank(address(mainRegistryExtension_New));
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // After check, exposures should be equal to 0
        (, uint128 AfterExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
        assert(AfterExposureUnderlyingAsset == 0);
        //assert(derivedPricingModule.usdExposureProtocol() == 0);
        assert(PRIMARY_FLAG == false);
        //assert(usdValueExposureUpperAssetToAsset == 0);
    }
}
