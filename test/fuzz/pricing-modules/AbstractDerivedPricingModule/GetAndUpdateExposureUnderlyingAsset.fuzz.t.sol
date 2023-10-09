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
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        bytes32 underlyingAssetKey =
            derivedPricingModule.getKeyFromAsset(assetState.underlyingAsset, assetState.underlyingAssetId);
        (uint256 exposureAssetToUnderlyingAssetActual, int256 deltaExposureAssetToUnderlyingAssetActual) =
        derivedPricingModule.getAndUpdateExposureUnderlyingAsset(
            assetKey, underlyingAssetKey, exposureAsset, assetState.conversionRate
        );

        // Then: Correct variables are returned.
        assertEq(exposureAssetToUnderlyingAssetActual, exposureAssetToUnderlyingAssetExpected);
        assertEq(deltaExposureAssetToUnderlyingAssetActual, deltaExposureAssetToUnderlyingAssetExpected);

        // And: "exposureAssetToUnderlyingAssetsLast" is updated.
        uint256 exposureAssetToUnderlyingAssetsActual =
            derivedPricingModule.getExposureAssetToUnderlyingAssetsLast(assetKey, underlyingAssetKey);
        assertEq(exposureAssetToUnderlyingAssetsActual, exposureAssetToUnderlyingAssetExpected);
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
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        bytes32 underlyingAssetKey =
            derivedPricingModule.getKeyFromAsset(assetState.underlyingAsset, assetState.underlyingAssetId);
        (uint256 exposureAssetToUnderlyingAssetActual, int256 deltaExposureAssetToUnderlyingAssetActual) =
        derivedPricingModule.getAndUpdateExposureUnderlyingAsset(
            assetKey, underlyingAssetKey, exposureAsset, assetState.conversionRate
        );

        // Then: Correct variables are returned.
        assertEq(exposureAssetToUnderlyingAssetActual, exposureAssetToUnderlyingAssetExpected);
        assertEq(deltaExposureAssetToUnderlyingAssetActual, deltaExposureAssetToUnderlyingAssetExpected);

        // And: "exposureAssetToUnderlyingAssetsLast" is updated.
        uint256 exposureAssetToUnderlyingAssetsActual =
            derivedPricingModule.getExposureAssetToUnderlyingAssetsLast(assetKey, underlyingAssetKey);
        assertEq(exposureAssetToUnderlyingAssetsActual, exposureAssetToUnderlyingAssetExpected);
    }
}
