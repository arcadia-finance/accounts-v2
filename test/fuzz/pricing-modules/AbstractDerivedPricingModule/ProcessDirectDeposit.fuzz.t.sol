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
    function testFuzz_Revert_processDirectDeposit_NonMainRegistry(
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

    function testFuzz_Success_processDirectDeposit(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 id,
        uint256 amount
    ) public {
        // Given: No overflow on exposureAsset.
        amount = bound(amount, 0, type(uint128).max - assetState.exposureAssetLast);
        uint256 exposureAsset = assetState.exposureAssetLast + amount;

        // And: No overflow on exposureAssetToUnderlyingAsset.
        if (exposureAsset != 0) {
            assetState.conversionRate =
                bound(assetState.conversionRate, 0, uint256(type(uint128).max) * 1e18 / exposureAsset);
        }

        // And: exposure does not exceeds max exposure.
        if (underlyingPMState.usdValueExposureToUnderlyingAsset >= assetState.usdValueExposureAssetLast) {
            // And: "usdExposureProtocol" does not overflow (unrealistically big).
            protocolState.usdExposureProtocolLast = bound(
                protocolState.usdExposureProtocolLast,
                assetState.usdValueExposureAssetLast,
                type(uint256).max
                    - (underlyingPMState.usdValueExposureToUnderlyingAsset - assetState.usdValueExposureAssetLast)
            );
            uint256 usdExposureProtocolExpected = protocolState.usdExposureProtocolLast
                + (underlyingPMState.usdValueExposureToUnderlyingAsset - assetState.usdValueExposureAssetLast);
            // And: exposure does not exceeds max exposure.
            protocolState.maxUsdExposureProtocol =
                bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected, type(uint256).max);
        }

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, underlyingPMState);

        // When: "MainRegistry" calls "processDirectDeposit".
        vm.prank(address(mainRegistryExtension_New));
        derivedPricingModule.processDirectDeposit(assetState.asset, id, amount);

        // Then: Transaction does not revert.
    }

    // function testFuzz_Revert_processDirectDeposit_OverExposureProtocol(
    //     address asset,
    //     address underlyingAsset,
    //     uint128 exposureAssetLast,
    //     uint128 amount,
    //     uint256 id,
    //     uint256 maxExposureProtocol
    // ) public {
    //     vm.assume(amount < type(uint128).max - exposureAssetLast);
    //     vm.assume(amount > 0);
    //     vm.assume(amount + exposureAssetLast > maxExposureProtocol);

    //     // Set exposure of underlying (primary) asset to max
    //     primaryPricingModule.setExposure(underlyingAsset, exposureAssetLast, type(uint128).max);
    //     // Set usd exposure of protocol to
    //     derivedPricingModule.setUsdExposureProtocol(maxExposureProtocol, exposureAssetLast);

    //     address[] memory underlyingAssets = new address[](1);
    //     underlyingAssets[0] = underlyingAsset;
    //     uint128[] memory exposureAssetToUnderlyingAssetsLast = new uint128[](1);
    //     exposureAssetToUnderlyingAssetsLast[0] = exposureAssetLast;

    //     // Add asset to pricing module
    //     derivedPricingModule.addAsset(asset, underlyingAssets);
    //     // Set asset info
    //     derivedPricingModule.setAssetInformation(
    //         asset, exposureAssetLast, exposureAssetLast, exposureAssetToUnderlyingAssetsLast
    //     );

    //     // Set the pricing module for the underlying asset in MainRegistry
    //     mainRegistryExtension_New.setPricingModuleForAsset(underlyingAsset, address(primaryPricingModule));

    //     vm.startPrank(address(mainRegistryExtension_New));
    //     vm.expectRevert("ADPM_PD: Exposure not in limits");
    //     derivedPricingModule.processDirectDeposit(asset, id, amount);
    //     vm.stopPrank();
    // }

    // For the cases in which a deposit would lead to an overall decrease in protocol usd exposure,
    // such scenarios are covered via testing done in processIndirectDeposit.fuzz.t.sol ending with
    // _negativeDeltaLessThanPreviousExposure and _negativeDeltaGreaterThanPreviousExposure
    // function testFuzz_Success_processDirectDeposit_increaseOfProtocolUsdExposure(
    //     address asset,
    //     address underlyingAsset,
    //     uint128 exposureAssetLast,
    //     uint128 amount,
    //     uint256 id
    // ) public {
    //     vm.assume(amount < type(uint128).max - exposureAssetLast);
    //     vm.assume(amount > 0);

    //     // Set exposure of underlying (primary) asset to max
    //     primaryPricingModule.setExposure(underlyingAsset, exposureAssetLast, type(uint128).max);
    //     // Set usd exposure of protocol to max
    //     derivedPricingModule.setUsdExposureProtocol(type(uint256).max, exposureAssetLast);

    //     address[] memory underlyingAssets = new address[](1);
    //     underlyingAssets[0] = underlyingAsset;
    //     uint128[] memory exposureAssetToUnderlyingAssetsLast = new uint128[](1);
    //     exposureAssetToUnderlyingAssetsLast[0] = exposureAssetLast;

    //     // Add asset to pricing module
    //     derivedPricingModule.addAsset(asset, underlyingAssets);
    //     // Set asset info
    //     derivedPricingModule.setAssetInformation(
    //         asset, exposureAssetLast, exposureAssetLast, exposureAssetToUnderlyingAssetsLast
    //     );

    //     // Set the pricing module for the underlying asset in MainRegistry
    //     mainRegistryExtension_New.setPricingModuleForAsset(underlyingAsset, address(primaryPricingModule));

    //     // Pre check
    //     (, uint128 PreExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
    //     assert(PreExposureUnderlyingAsset == exposureAssetLast);
    //     assert(derivedPricingModule.usdExposureProtocol() == exposureAssetLast);

    //     vm.prank(address(mainRegistryExtension_New));
    //     derivedPricingModule.processDirectDeposit(asset, id, amount);

    //     // After check, exposures should have increased
    //     (, uint128 AfterExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
    //     assert(AfterExposureUnderlyingAsset == exposureAssetLast + amount);
    //     //assert(derivedPricingModule.usdExposureProtocol() == exposureAssetLast + amount);
    // }
}
