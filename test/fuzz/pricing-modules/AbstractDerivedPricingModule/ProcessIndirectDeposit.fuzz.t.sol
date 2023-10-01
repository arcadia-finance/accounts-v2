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
    function testFuzz_Revert_processIndirectDeposit_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension_New));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        derivedPricingModule.processIndirectDeposit(
            asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit_ZeroExposureAsset(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: Underflow on exposureAsset (test-case).
        deltaExposureUpperAssetToAsset =
            bound(deltaExposureUpperAssetToAsset, assetState.exposureAssetLast, uint256(type(int256).max));
        int256 deltaExposureUpperAssetToAsset_ = -int256(deltaExposureUpperAssetToAsset);

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
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            assetState.asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset_
        );

        // Then: PRIMARY_FLAG is false.
        assertFalse(PRIMARY_FLAG);

        // And:
        assertEq(usdValueExposureUpperAssetToAsset, 0);
    }

    function testFuzz_Success_processIndirectDeposit_ZeroUsdValueExposureAsset(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "usdValueExposureAsset" is 0 (test-case).
        underlyingPMState.usdValueExposureToUnderlyingAsset = 0;

        // And: no overflow on cast.
        vm.assume(
            deltaExposureUpperAssetToAsset
                > -57_896_044_618_658_097_711_785_492_504_343_953_926_634_992_332_820_282_019_728_792_003_956_564_819_968
        );

        if (deltaExposureUpperAssetToAsset > 0) {
            // Given: No overflow on exposureAsset.
            deltaExposureUpperAssetToAsset = int256(
                bound(uint256(deltaExposureUpperAssetToAsset), 0, type(uint128).max - assetState.exposureAssetLast)
            );
            uint256 exposureAsset = assetState.exposureAssetLast + uint256(deltaExposureUpperAssetToAsset);

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
        } else {
            uint256 exposureAsset;
            if (uint256(-deltaExposureUpperAssetToAsset) < assetState.exposureAssetLast) {
                exposureAsset = assetState.exposureAssetLast - uint256(-deltaExposureUpperAssetToAsset);
            }

            // And: No overflow on exposureAssetToUnderlyingAsset.
            if (exposureAsset != 0) {
                assetState.conversionRate =
                    bound(assetState.conversionRate, 0, uint256(type(uint128).max) * 1e18 / exposureAsset);
            }
            // And: exposure does not overflow.
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
        }

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, underlyingPMState);

        // When: "MainRegistry" calls "processIndirectDeposit".
        vm.prank(address(mainRegistryExtension_New));
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            assetState.asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // Then: PRIMARY_FLAG is false.
        assertFalse(PRIMARY_FLAG);

        // And:
        assertEq(usdValueExposureUpperAssetToAsset, 0);
    }

    function testFuzz_Success_processIndirectDeposit_NonZeroValues(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: usdValueExposureToUnderlyingAsset does not overflow.
        underlyingPMState.usdValueExposureToUnderlyingAsset =
            bound(underlyingPMState.usdValueExposureToUnderlyingAsset, 1, type(uint128).max);

        // And: "usdValueExposureUpperAssetToAsset" does not overflow (unrealistic big values).
        exposureUpperAssetToAsset =
            bound(exposureUpperAssetToAsset, 0, type(uint256).max / underlyingPMState.usdValueExposureToUnderlyingAsset);

        // And: no overflow on cast.
        vm.assume(
            deltaExposureUpperAssetToAsset
                > -57_896_044_618_658_097_711_785_492_504_343_953_926_634_992_332_820_282_019_728_792_003_956_564_819_968
        );

        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            // Given: No overflow on exposureAsset.
            deltaExposureUpperAssetToAsset = int256(
                bound(uint256(deltaExposureUpperAssetToAsset), 0, type(uint128).max - assetState.exposureAssetLast)
            );
            exposureAsset = assetState.exposureAssetLast + uint256(deltaExposureUpperAssetToAsset);

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
        } else {
            vm.assume(uint256(-deltaExposureUpperAssetToAsset) < assetState.exposureAssetLast);
            exposureAsset = uint256(assetState.exposureAssetLast) - uint256(-deltaExposureUpperAssetToAsset);

            // And: No overflow on exposureAssetToUnderlyingAsset.
            assetState.conversionRate =
                bound(assetState.conversionRate, 0, uint256(type(uint128).max) * 1e18 / exposureAsset);

            // And: exposure does not overflow.
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
        }

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, underlyingPMState);

        // When: "MainRegistry" calls "processIndirectDeposit".
        vm.prank(address(mainRegistryExtension_New));
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            assetState.asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // Then: PRIMARY_FLAG is false.
        assertFalse(PRIMARY_FLAG);

        // And: Correct "usdValueExposureUpperAssetToAsset" is returned.
        uint256 usdValueExposureUpperAssetToAssetExpected =
            underlyingPMState.usdValueExposureToUnderlyingAsset * exposureUpperAssetToAsset / exposureAsset;
        assertEq(usdValueExposureUpperAssetToAsset, usdValueExposureUpperAssetToAssetExpected);
    }

    // function testFuzz_Success_processIndirectDeposit_positiveDelta(
    //     address asset,
    //     address underlyingAsset,
    //     uint128 exposureAssetLast,
    //     int256 deltaExposureUpperAssetToAsset,
    //     uint256 id,
    //     uint256 exposureUpperAssetToAsset
    // ) public {
    //     vm.assume(deltaExposureUpperAssetToAsset > 0);
    //     vm.assume(uint256(deltaExposureUpperAssetToAsset) < type(uint128).max - exposureAssetLast);
    //     vm.assume(exposureUpperAssetToAsset < type(uint128).max);

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
    //     (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
    //         asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
    //     );

    //     // After check, exposures should have increased
    //     (, uint128 AfterExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
    //     assert(AfterExposureUnderlyingAsset == exposureAssetLast + uint256(deltaExposureUpperAssetToAsset));
    //     //assert(
    //     //    derivedPricingModule.usdExposureProtocol() == exposureAssetLast + uint256(deltaExposureUpperAssetToAsset)
    //     //);
    //     assert(PRIMARY_FLAG == false);
    //     //assert(usdValueExposureUpperAssetToAsset == exposureUpperAssetToAsset);
    // }

    // function testFuzz_Success_processIndirectDeposit_negativeDeltaLessThanPreviousExposure(
    //     address asset,
    //     address underlyingAsset,
    //     uint128 exposureAssetLast,
    //     int256 deltaExposureUpperAssetToAsset,
    //     uint256 id,
    //     uint256 exposureUpperAssetToAsset
    // ) public {
    //     vm.assume(deltaExposureUpperAssetToAsset < 0);
    //     vm.assume(deltaExposureUpperAssetToAsset > type(int128).min);
    //     vm.assume(uint256(-deltaExposureUpperAssetToAsset) < exposureAssetLast);
    //     vm.assume(exposureUpperAssetToAsset < type(uint128).max);

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
    //     (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
    //         asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
    //     );

    //     // After check, exposures should have increased
    //     (, uint128 AfterExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
    //     assert(AfterExposureUnderlyingAsset == exposureAssetLast - uint256(-deltaExposureUpperAssetToAsset));
    //     //assert(
    //     //    derivedPricingModule.usdExposureProtocol() == exposureAssetLast - uint256(-deltaExposureUpperAssetToAsset)
    //     //);
    //     assert(PRIMARY_FLAG == false);
    //     //assert(usdValueExposureUpperAssetToAsset == exposureUpperAssetToAsset);
    // }

    // function testFuzz_Success_processIndirectDeposit_negativeDeltaGreaterThanPreviousExposure(
    //     address asset,
    //     address underlyingAsset,
    //     uint128 exposureAssetLast,
    //     int256 deltaExposureUpperAssetToAsset,
    //     uint256 id,
    //     uint256 exposureUpperAssetToAsset
    // ) public {
    //     vm.assume(deltaExposureUpperAssetToAsset < 0);
    //     vm.assume(deltaExposureUpperAssetToAsset > type(int128).min);
    //     vm.assume(uint256(-deltaExposureUpperAssetToAsset) > exposureAssetLast);
    //     vm.assume(exposureUpperAssetToAsset < type(uint128).max);

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
    //     (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
    //         asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
    //     );

    //     // After check, exposures should be equal to 0
    //     (, uint128 AfterExposureUnderlyingAsset) = primaryPricingModule.exposure(underlyingAsset);
    //     assert(AfterExposureUnderlyingAsset == 0);
    //     //assert(derivedPricingModule.usdExposureProtocol() == 0);
    //     assert(PRIMARY_FLAG == false);
    //     //assert(usdValueExposureUpperAssetToAsset == 0);
    // }
}
