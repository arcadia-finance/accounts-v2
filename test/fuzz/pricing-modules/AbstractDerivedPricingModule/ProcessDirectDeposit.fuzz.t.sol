/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule_New.sol";

/**
 * @notice Fuzz tests for the "processDirectDeposit" of contract "AbstractDerivedPricingModule".
 * @notice Tests performed here will validate the recursion flow of derived pricing modules.
 * Testing for conversion rates and getValue() will be done in pricing modules testing separately.
 */
contract ProcessDirectDeposit_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NotMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint256 id,
        uint128 amount
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension_New));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        derivedPricingModule.processDirectDeposit(asset, id, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_OverExposureProtocol(
        address asset,
        address underlyingAsset,
        uint128 exposureAssetLast,
        uint128 amount,
        uint256 id,
        uint256 maxExposureProtocol
    ) public {
        vm.assume(amount < type(uint128).max - exposureAssetLast);
        vm.assume(amount > 0);
        vm.assume(amount + exposureAssetLast > maxExposureProtocol);

        // Set exposure of underlying (primary) asset to max
        primaryPricingModule.setExposure(underlyingAsset, exposureAssetLast, type(uint128).max);
        // Set usd exposure of protocol to
        derivedPricingModule.setExposure(maxExposureProtocol, exposureAssetLast);

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

        vm.startPrank(address(mainRegistryExtension_New));
        vm.expectRevert("ADPM_PD: Exposure not in limits");
        derivedPricingModule.processDirectDeposit(asset, id, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(
        address asset,
        address underlyingAsset,
        uint128 exposureAssetLast,
        uint128 amount,
        uint256 id
    ) public {
        vm.assume(amount < type(uint128).max - exposureAssetLast);
        vm.assume(amount > 0);

        // Set exposure of underlying (primary) asset to max
        primaryPricingModule.setExposure(underlyingAsset, exposureAssetLast, type(uint128).max);
        // Set usd exposure of protocol to max
        derivedPricingModule.setExposure(type(uint256).max, exposureAssetLast);

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
        derivedPricingModule.processDirectDeposit(asset, id, amount);

        // After check, exposures should have increased
        (, uint128 AfterExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
        assert(AfterExposureUnderlyingAsset == exposureAssetLast + amount);
        assert(derivedPricingModule.usdExposureProtocol() == exposureAssetLast + amount);
    }
}
