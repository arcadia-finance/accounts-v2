/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "_getAndUpdateExposureAsset" of contract "AbstractDerivedPricingModule".
 */
contract GetAndUpdateExposureAsset_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAndUpdateExposureAsset_PositiveDelta(
        DerivedPricingModuleAssetState memory assetState,
        uint256 deltaAsset
    ) public {
        // Given: No overflow on exposureAsset.
        deltaAsset = bound(deltaAsset, 0, type(uint128).max - assetState.exposureAssetLast);

        // And: delta is positive (test-case).
        int256 deltaAsset_ = int256(deltaAsset);

        // And: "assetState" is persisted.
        setDerivedPricingModuleAssetState(assetState);

        // When: "getAndUpdateExposureAsset" is called.
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, 0);
        uint256 exposureAssetActual = derivedPricingModule.getAndUpdateExposureAsset(assetKey, deltaAsset_);

        // Then: Correct "exposureAsset" is returned.
        uint256 exposureAssetExpected = assetState.exposureAssetLast + deltaAsset;
        assertEq(exposureAssetActual, exposureAssetExpected);

        // And: "exposureAsset" is updated.
        (exposureAssetActual,,,) = derivedPricingModule.getAssetInformation(assetState.asset);
        assertEq(exposureAssetExpected, exposureAssetExpected);
    }

    function testFuzz_Success_getAndUpdateExposureAsset_NegativeDelta_NoUnderflow(
        DerivedPricingModuleAssetState memory assetState,
        uint256 deltaAsset
    ) public {
        // Given: No underflow on exposureAsset (test-case)..
        deltaAsset = bound(deltaAsset, 0, assetState.exposureAssetLast);

        // And: delta is negative (test-case).
        int256 deltaAsset_ = -int256(deltaAsset);

        // And: "assetState" is persisted.
        setDerivedPricingModuleAssetState(assetState);

        // When: "getAndUpdateExposureAsset" is called.
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, 0);
        uint256 exposureAssetActual = derivedPricingModule.getAndUpdateExposureAsset(assetKey, deltaAsset_);

        // Then: Correct "exposureAsset" is returned.
        uint256 exposureAssetExpected = assetState.exposureAssetLast - deltaAsset;
        assertEq(exposureAssetActual, exposureAssetExpected);

        // And: "exposureAsset" is updated.
        (exposureAssetActual,,,) = derivedPricingModule.getAssetInformation(assetState.asset);
        assertEq(exposureAssetExpected, exposureAssetExpected);
    }

    function testFuzz_Success_getAndUpdateExposureAsset_NegativeDelta_Underflow(
        DerivedPricingModuleAssetState memory assetState,
        uint256 deltaAsset
    ) public {
        // Given: Underflow on exposureAsset (test-case).
        deltaAsset = bound(deltaAsset, assetState.exposureAssetLast, uint256(type(int256).max));

        // And: delta is negative (test-case).
        int256 deltaAsset_ = -int256(deltaAsset);

        // And: "assetState" is persisted.
        setDerivedPricingModuleAssetState(assetState);

        // When: "getAndUpdateExposureAsset" is called.
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, 0);
        uint256 exposureAssetActual = derivedPricingModule.getAndUpdateExposureAsset(assetKey, deltaAsset_);

        // Then: Correct "exposureAsset" is returned.
        uint256 exposureAssetExpected = 0;
        assertEq(exposureAssetActual, exposureAssetExpected);

        // And: "exposureAsset" is updated.
        (exposureAssetActual,,,) = derivedPricingModule.getAssetInformation(assetState.asset);
        assertEq(exposureAssetExpected, exposureAssetExpected);
    }
}
