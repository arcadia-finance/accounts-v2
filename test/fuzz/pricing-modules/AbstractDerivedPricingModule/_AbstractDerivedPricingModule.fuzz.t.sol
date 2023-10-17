/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";
import { DerivedPricingModuleMock } from "../../../utils/mocks/DerivedPricingModuleMock.sol";
import { PrimaryPricingModuleMock } from "../../../utils/mocks/PrimaryPricingModuleMock.sol";

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
        uint256 assetId;
        uint128 exposureAssetLast;
        uint128 usdValueExposureAssetLast;
        address underlyingAsset;
        uint256 underlyingAssetId;
        uint256 exposureAssetToUnderlyingAsset;
        uint128 exposureAssetToUnderlyingAssetsLast;
    }

    struct UnderlyingPricingModuleState {
        uint128 exposureAssetLast;
        uint256 usdValueExposureToUnderlyingAsset;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    DerivedPricingModuleMock internal derivedPricingModule;
    PrimaryPricingModuleMock internal primaryPricingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        derivedPricingModule = new DerivedPricingModuleMock(address(mainRegistryExtension), 0, users.creatorAddress);

        primaryPricingModule = new PrimaryPricingModuleMock(address(mainRegistryExtension), address(oracleHub), 0);

        mainRegistryExtension.addPricingModule(address(derivedPricingModule));
        mainRegistryExtension.addPricingModule(address(primaryPricingModule));

        // We assume conversion rate and price of underlying asset both equal to 1.
        // Conversion rate and prices of underlying assets will be tested in specific pricing modules.
        derivedPricingModule.setUnderlyingAssetsAmount(1e18);

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
        uint256[] memory underlyingAssetIds = new uint256[](1);
        underlyingAssetIds[0] = assetState.underlyingAssetId;
        derivedPricingModule.addAsset(assetState.asset, assetState.assetId, underlyingAssets, underlyingAssetIds);

        derivedPricingModule.setUnderlyingAssetsAmount(assetState.exposureAssetToUnderlyingAsset);

        derivedPricingModule.setAssetInformation(
            assetState.asset,
            assetState.assetId,
            assetState.underlyingAsset,
            assetState.underlyingAssetId,
            assetState.exposureAssetLast,
            assetState.usdValueExposureAssetLast,
            assetState.exposureAssetToUnderlyingAssetsLast
        );
    }

    function setUnderlyingPricingModuleState(
        address underlyingAsset,
        uint256 underlyingAssetId,
        UnderlyingPricingModuleState memory underlyingPMState
    ) internal {
        // Set mapping between underlying Asset and its pricing module in the Main Registry.
        mainRegistryExtension.setPricingModuleForAsset(underlyingAsset, address(primaryPricingModule));

        // Set max exposure of mocked Pricing Module for Underlying assets.
        vm.prank(users.creatorAddress);
        primaryPricingModule.setExposureOfAsset(underlyingAsset, underlyingAssetId, type(uint128).max);

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
        // Given: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

        // And: usd Value of protocol is bigger or equal to each individual usd value of an asset (Invariant).
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

        // And: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

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
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint128).max);

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

        // And: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

        return (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
    }
}
