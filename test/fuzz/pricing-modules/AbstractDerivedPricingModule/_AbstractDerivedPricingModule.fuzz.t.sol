/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule_New.sol";
import {
    AbstractDerivedPricingModuleExtension,
    AbstractPrimaryPricingModuleExtension,
    MainRegistryExtension_New
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
    MainRegistryExtension_New internal mainRegistryExtension_New;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        mainRegistryExtension_New = new MainRegistryExtension_New(address(factory));

        derivedPricingModule =
        new AbstractDerivedPricingModuleExtension(address(mainRegistryExtension_New), address(oracleHub), 0, users.creatorAddress);

        primaryPricingModule =
        new AbstractPrimaryPricingModuleExtension(address(mainRegistryExtension_New), address(oracleHub), 0, users.creatorAddress);

        mainRegistryExtension_New.addPricingModule(address(derivedPricingModule));
        mainRegistryExtension_New.addPricingModule(address(primaryPricingModule));

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

        uint128[] memory exposureAssetToUnderlyingAssetsLast = new uint128[](1);
        exposureAssetToUnderlyingAssetsLast[0] = assetState.exposureAssetToUnderlyingAssetsLast;
        derivedPricingModule.setAssetInformation(
            assetState.asset,
            assetState.exposureAssetLast,
            assetState.usdValueExposureAssetLast,
            exposureAssetToUnderlyingAssetsLast
        );
    }

    function setUnderlyingPricingModuleState(
        address underlyingAsset,
        UnderlyingPricingModuleState memory underlyingPMState
    ) internal {
        // Set mapping between underlying Asset and its pricing module in the Main Registry.
        mainRegistryExtension_New.setPricingModuleForAsset(underlyingAsset, address(primaryPricingModule));

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
}
