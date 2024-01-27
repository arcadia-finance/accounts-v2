/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractDerivedAM_Fuzz_Test } from "./_AbstractDerivedAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getAndUpdateExposureAsset" of contract "AbstractDerivedAM".
 */
contract GetAndUpdateExposureAsset_AbstractDerivedAM_Fuzz_Test is AbstractDerivedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAndUpdateExposureAsset_PositiveDelta(
        DerivedAMAssetState memory assetState,
        uint256 deltaAsset
    ) public {
        // Given: No overflow on exposureAsset.
        deltaAsset = bound(deltaAsset, 0, type(uint112).max - assetState.exposureAssetLast);

        // And: delta is positive (test-case).
        int256 deltaAsset_ = int256(deltaAsset);

        // And: "assetState" is persisted.
        setDerivedAMAssetState(assetState);

        // When: "getAndUpdateExposureAsset" is called.
        bytes32 assetKey = derivedAM.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 exposureAssetActual = derivedAM.getAndUpdateExposureAsset(assetState.creditor, assetKey, deltaAsset_);

        // Then: Correct "exposureAsset" is returned.
        uint256 exposureAssetExpected = assetState.exposureAssetLast + deltaAsset;
        assertEq(exposureAssetActual, exposureAssetExpected);

        // And: "exposureAsset" is updated.
        (exposureAssetActual,) = derivedAM.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(exposureAssetActual, exposureAssetExpected);
    }

    function testFuzz_Success_getAndUpdateExposureAsset_NegativeDelta_NoUnderflow(
        DerivedAMAssetState memory assetState,
        uint256 deltaAsset
    ) public {
        // Given: No underflow on exposureAsset (test-case)..
        deltaAsset = bound(deltaAsset, 0, assetState.exposureAssetLast);

        // And: delta is negative (test-case).
        int256 deltaAsset_ = -int256(deltaAsset);

        // And: "assetState" is persisted.
        setDerivedAMAssetState(assetState);

        // When: "getAndUpdateExposureAsset" is called.
        bytes32 assetKey = derivedAM.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 exposureAssetActual = derivedAM.getAndUpdateExposureAsset(assetState.creditor, assetKey, deltaAsset_);

        // Then: Correct "exposureAsset" is returned.
        uint256 exposureAssetExpected = assetState.exposureAssetLast - deltaAsset;
        assertEq(exposureAssetActual, exposureAssetExpected);

        // And: "exposureAsset" is updated.
        (exposureAssetActual,) = derivedAM.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(exposureAssetActual, exposureAssetExpected);
    }

    function testFuzz_Success_getAndUpdateExposureAsset_NegativeDelta_Underflow(
        DerivedAMAssetState memory assetState,
        uint256 deltaAsset
    ) public {
        // Given: Underflow on exposureAsset (test-case).
        deltaAsset = bound(deltaAsset, assetState.exposureAssetLast, uint256(type(int256).max));

        // And: delta is negative (test-case).
        int256 deltaAsset_ = -int256(deltaAsset);

        // And: "assetState" is persisted.
        setDerivedAMAssetState(assetState);

        // When: "getAndUpdateExposureAsset" is called.
        bytes32 assetKey = derivedAM.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 exposureAssetActual = derivedAM.getAndUpdateExposureAsset(assetState.creditor, assetKey, deltaAsset_);

        // Then: Correct "exposureAsset" is returned.
        uint256 exposureAssetExpected = 0;
        assertEq(exposureAssetActual, exposureAssetExpected);

        // And: "exposureAsset" is updated.
        (exposureAssetActual,) = derivedAM.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(exposureAssetActual, exposureAssetExpected);
    }
}
