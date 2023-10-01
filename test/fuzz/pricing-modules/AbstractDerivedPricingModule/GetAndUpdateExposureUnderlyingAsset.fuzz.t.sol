/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "_getAndUpdateExposureUnderlyingAsset" of contract "AbstractDerivedPricingModule".
 */
contract GetAndUpdateExposureUnderlyingAsset_AbstractDerivedPricingModule_Fuzz_Test is
    AbstractDerivedPricingModule_Fuzz_Test
{
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAndUpdateExposureUnderlyingAsset_PositiveDelta(
        DerivedPricingModuleAssetState memory assetState,
        uint128 exposureAsset
    ) public {
        // Given: No overflow on exposureAssetToUnderlyingAsset.
        if (exposureAsset != 0) {
            assetState.conversionRate =
                bound(assetState.conversionRate, 0, uint256(type(uint128).max) * 1e18 / exposureAsset);
        }

        // And: delta is positive (test-case).
        uint256 exposureAssetToUnderlyingAssetExpected = assetState.conversionRate * exposureAsset / 1e18;
        assetState.exposureAssetToUnderlyingAssetsLast =
            uint128(bound(assetState.exposureAssetToUnderlyingAssetsLast, 0, exposureAssetToUnderlyingAssetExpected));
        int256 deltaExposureAssetToUnderlyingAssetExpected =
            int256(exposureAssetToUnderlyingAssetExpected - assetState.exposureAssetToUnderlyingAssetsLast);

        // And: "assetState" is persisted.
        setDerivedPricingModuleAssetState(assetState);

        // When: "_getAndUpdateExposureUnderlyingAsset" is called.
        (uint256 exposureAssetToUnderlyingAssetActual, int256 deltaExposureAssetToUnderlyingAssetActual) =
        derivedPricingModule.getAndUpdateExposureUnderlyingAsset(
            assetState.asset, exposureAsset, assetState.conversionRate, 0
        );

        // Then: Correct variables are returned.
        assertEq(exposureAssetToUnderlyingAssetActual, exposureAssetToUnderlyingAssetExpected);
        assertEq(deltaExposureAssetToUnderlyingAssetActual, deltaExposureAssetToUnderlyingAssetExpected);

        // And: "exposureAssetToUnderlyingAssetsLast" is updated.
        (,,, uint128[] memory exposureAssetToUnderlyingAssetsLast) =
            derivedPricingModule.getAssetInformation(assetState.asset);
        assertEq(exposureAssetToUnderlyingAssetsLast[0], exposureAssetToUnderlyingAssetExpected);
    }

    function testFuzz_Success_getAndUpdateExposureUnderlyingAsset_NegativeDelta(
        DerivedPricingModuleAssetState memory assetState,
        uint128 exposureAsset
    ) public {
        // Given: No overflow on exposureAssetToUnderlyingAsset.
        if (exposureAsset != 0) {
            assetState.conversionRate =
                bound(assetState.conversionRate, 0, uint256(type(uint128).max) * 1e18 / exposureAsset);
        }

        // And: delta is positive (test-case).
        uint256 exposureAssetToUnderlyingAssetExpected = assetState.conversionRate * exposureAsset / 1e18;
        assetState.exposureAssetToUnderlyingAssetsLast = uint128(
            bound(
                assetState.exposureAssetToUnderlyingAssetsLast,
                exposureAssetToUnderlyingAssetExpected,
                type(uint128).max
            )
        );
        int256 deltaExposureAssetToUnderlyingAssetExpected =
            -int256(assetState.exposureAssetToUnderlyingAssetsLast - exposureAssetToUnderlyingAssetExpected);

        // And: "assetState" is persisted.
        setDerivedPricingModuleAssetState(assetState);

        // When: "_getAndUpdateExposureUnderlyingAsset" is called.
        (uint256 exposureAssetToUnderlyingAssetActual, int256 deltaExposureAssetToUnderlyingAssetActual) =
        derivedPricingModule.getAndUpdateExposureUnderlyingAsset(
            assetState.asset, exposureAsset, assetState.conversionRate, 0
        );

        // Then: Correct variables are returned.
        assertEq(exposureAssetToUnderlyingAssetActual, exposureAssetToUnderlyingAssetExpected);
        assertEq(deltaExposureAssetToUnderlyingAssetActual, deltaExposureAssetToUnderlyingAssetExpected);

        // And: "exposureAssetToUnderlyingAssetsLast" is updated.
        (,,, uint128[] memory exposureAssetToUnderlyingAssetsLast) =
            derivedPricingModule.getAssetInformation(assetState.asset);
        assertEq(exposureAssetToUnderlyingAssetsLast[0], exposureAssetToUnderlyingAssetExpected);
    }
}
