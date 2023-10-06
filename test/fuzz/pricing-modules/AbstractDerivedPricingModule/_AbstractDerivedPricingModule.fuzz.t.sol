/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import {
    AbstractDerivedPricingModuleExtension,
    AbstractPrimaryPricingModuleExtension,
    MainRegistryExtension
} from "../../../utils/Extensions.sol";
import { AbstractPrimaryPricingModuleExtension } from "../../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "DerivedPricingModule" fuzz tests.
 */
abstract contract AbstractDerivedPricingModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct DerivedPricingModuleProtocolState {
        uint256 usdExposureProtocolLast;
        uint256 maxUsdExposureProtocol;
    }

    struct DerivedPricingModuleAssetState {
        address asset;
        uint128 exposureAssetLast;
        uint128 usdValueExposureAssetLast;
        address underlyingAsset;
        uint256 conversionRate;
        uint128 exposureAssetToUnderlyingAssetsLast;
    }

    struct UnderlyingPricingModuleState {
        uint128 exposureAssetLast;
        uint256 usdValueExposureToUnderlyingAsset;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    AbstractDerivedPricingModuleExtension internal derivedPricingModule;
    AbstractPrimaryPricingModuleExtension internal primaryPricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        derivedPricingModule =
        new AbstractDerivedPricingModuleExtension(address(mainRegistryExtension), address(oracleHub), 0, users.creatorAddress);

        primaryPricingModule =
        new AbstractPrimaryPricingModuleExtension(address(mainRegistryExtension), address(oracleHub), 0, users.creatorAddress);

        mainRegistryExtension.addPricingModule(address(derivedPricingModule));
        mainRegistryExtension.addPricingModule(address(primaryPricingModule));

        // We assume conversion rate and price of underlying asset both equal to 1.
        // Conversion rate and prices of underlying assets will be tested in specific pricing modules.
        derivedPricingModule.setConversionRate(1e18);

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function setDerivedPricingModuleProtocolState(DerivedPricingModuleProtocolState memory protocolState) internal {
        derivedPricingModule.setUsdExposureProtocol(
            protocolState.maxUsdExposureProtocol, protocolState.usdExposureProtocolLast
        );
    }

    function setDerivedPricingModuleAssetState(DerivedPricingModuleAssetState memory assetState) internal {
        address[] memory underlyingAssets = new address[](1);
        underlyingAssets[0] = assetState.underlyingAsset;
        derivedPricingModule.addAsset(assetState.asset, underlyingAssets);

        derivedPricingModule.setConversionRate(assetState.conversionRate);

        derivedPricingModule.setAssetInformation(
            assetState.asset,
            assetState.underlyingAsset,
            assetState.exposureAssetLast,
            assetState.usdValueExposureAssetLast,
            assetState.exposureAssetToUnderlyingAssetsLast
        );
    }

    function setUnderlyingPricingModuleState(
        address underlyingAsset,
        UnderlyingPricingModuleState memory underlyingPMState
    ) internal {
        // Set mapping between underlying Asset and its pricing module in the Main Registry.
        mainRegistryExtension.setPricingModuleForAsset(underlyingAsset, address(primaryPricingModule));

        // Set max exposure of mocked Pricing Module for Underlying assets.
        vm.prank(users.creatorAddress);
        primaryPricingModule.setExposureOfAsset(underlyingAsset, type(uint128).max);

        // Mock the "usdValueExposureToUnderlyingAsset".
        primaryPricingModule.setPrice(underlyingPMState.usdValueExposureToUnderlyingAsset);
    }

    function givenValidState(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState
    )
        internal
        view
        returns (
            DerivedPricingModuleProtocolState memory,
            DerivedPricingModuleAssetState memory,
            UnderlyingPricingModuleState memory
        )
    {
        // Invariant: usd Value of protocol is bigger or equal to each individual usd value of an asset.
        assetState.usdValueExposureAssetLast =
            uint128(bound(assetState.usdValueExposureAssetLast, 0, protocolState.usdExposureProtocolLast));

        return (protocolState, assetState, underlyingPMState);
    }

    function givenNonRevertingWithdrawal(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    )
        internal
        view
        returns (
            DerivedPricingModuleProtocolState memory,
            DerivedPricingModuleAssetState memory,
            UnderlyingPricingModuleState memory,
            uint256,
            int256
        )
    {
        // Given: "usdValueExposureToUnderlyingAsset" does not overflow.
        underlyingPMState.usdValueExposureToUnderlyingAsset =
            bound(underlyingPMState.usdValueExposureToUnderlyingAsset, 0, type(uint128).max);

        // And: "usdValueExposureUpperAssetToAsset" does not overflow (unrealistic big values).
        if (underlyingPMState.usdValueExposureToUnderlyingAsset != 0) {
            exposureUpperAssetToAsset = bound(
                exposureUpperAssetToAsset, 0, type(uint256).max / underlyingPMState.usdValueExposureToUnderlyingAsset
            );
        }

        // Calculate exposureAsset.
        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            // Given: No overflow on exposureAsset.
            deltaExposureUpperAssetToAsset = int256(
                bound(uint256(deltaExposureUpperAssetToAsset), 0, type(uint128).max - assetState.exposureAssetLast)
            );

            exposureAsset = assetState.exposureAssetLast + uint256(deltaExposureUpperAssetToAsset);
        } else {
            // And: No overflow on negation most negative int256 (this overflows).
            vm.assume(deltaExposureUpperAssetToAsset > type(int256).min);

            if (uint256(-deltaExposureUpperAssetToAsset) < assetState.exposureAssetLast) {
                exposureAsset = uint256(assetState.exposureAssetLast) - uint256(-deltaExposureUpperAssetToAsset);
            }
        }

        // And: No overflow on exposureAssetToUnderlyingAsset.
        if (exposureAsset != 0) {
            assetState.conversionRate =
                bound(assetState.conversionRate, 0, uint256(type(uint128).max) * 1e18 / exposureAsset);
        }

        if (underlyingPMState.usdValueExposureToUnderlyingAsset >= assetState.usdValueExposureAssetLast) {
            // And: "usdExposureProtocol" does not overflow (unrealistically big).
            protocolState.usdExposureProtocolLast = bound(
                protocolState.usdExposureProtocolLast,
                assetState.usdValueExposureAssetLast,
                type(uint256).max
                    - (underlyingPMState.usdValueExposureToUnderlyingAsset - assetState.usdValueExposureAssetLast)
            );
        }

        return (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
    }

    function givenNonRevertingDeposit(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    )
        internal
        view
        returns (
            DerivedPricingModuleProtocolState memory,
            DerivedPricingModuleAssetState memory,
            UnderlyingPricingModuleState memory,
            uint256,
            int256
        )
    {
        // Identical bounds as for Withdrawals.
        (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset) =
        givenNonRevertingWithdrawal(
            protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // And: exposure does not exceeds max exposure.
        if (underlyingPMState.usdValueExposureToUnderlyingAsset >= assetState.usdValueExposureAssetLast) {
            uint256 usdExposureProtocolExpected = protocolState.usdExposureProtocolLast
                + (underlyingPMState.usdValueExposureToUnderlyingAsset - assetState.usdValueExposureAssetLast);

            protocolState.maxUsdExposureProtocol =
                bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected, type(uint256).max);
        }

        return (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
    }
}
