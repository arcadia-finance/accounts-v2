/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { stdError } from "../../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "_processWithdrawal" of contract "AbstractDerivedPricingModule".
 */
contract ProcessWithdrawal_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processWithdrawal_PositiveDeltaUsdExposure_Overflow(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: No overflow on exposureAssetToUnderlyingAsset.
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint128).max);

        // And: delta "usdValueExposureAsset" is positive (test-case).
        vm.assume(assetState.usdValueExposureAssetLast < type(uint128).max);
        underlyingPMState.usdValue =
            bound(underlyingPMState.usdValue, assetState.usdValueExposureAssetLast + 1, type(uint128).max);

        // And: "usdExposureProtocol" overflows (unrealistically big).
        protocolState.usdExposureProtocolLast = bound(
            protocolState.usdExposureProtocolLast,
            type(uint256).max - (underlyingPMState.usdValue - assetState.usdValueExposureAssetLast) + 1,
            type(uint256).max
        );

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, assetState.underlyingAssetId, underlyingPMState);

        // When: "_processWithdrawal" is called.
        // Then: The transaction reverts with arithmetic overflow.
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        vm.expectRevert(stdError.arithmeticError);
        derivedPricingModule.processWithdrawal(assetKey, exposureAsset);
    }

    function testFuzz_Success_processWithdrawal_PositiveDeltaUsdExposure(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: No overflow on exposureAssetToUnderlyingAsset.
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint128).max);

        // And: delta "usdValueExposureAsset" is positive (test-case).
        underlyingPMState.usdValue =
            bound(underlyingPMState.usdValue, assetState.usdValueExposureAssetLast, type(uint128).max);

        // And: "usdExposureProtocol" does not overflow (unrealistically big).
        protocolState.usdExposureProtocolLast = bound(
            protocolState.usdExposureProtocolLast,
            assetState.usdValueExposureAssetLast,
            type(uint256).max - (underlyingPMState.usdValue - assetState.usdValueExposureAssetLast)
        );
        uint256 usdExposureProtocolExpected =
            protocolState.usdExposureProtocolLast + (underlyingPMState.usdValue - assetState.usdValueExposureAssetLast);

        // And: exposure does not exceeds max exposure.
        protocolState.maxUsdExposureProtocol =
            bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected, type(uint256).max);

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, assetState.underlyingAssetId, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Pricing Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.exposureAssetToUnderlyingAssetsLast));
        bytes memory data = abi.encodeCall(
            mainRegistryExtension.getUsdValueExposureToUnderlyingAssetAfterWithdrawal,
            (
                assetState.underlyingAsset,
                assetState.underlyingAssetId,
                assetState.exposureAssetToUnderlyingAsset,
                deltaExposureAssetToUnderlyingAsset
            )
        );

        // When: "_processDeposit" is called.
        // Then: The Function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" on "MainRegistry" is called with correct parameters.
        vm.expectCall(address(mainRegistryExtension), data);
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdValueExposureAsset = derivedPricingModule.processWithdrawal(assetKey, exposureAsset);

        // Then: Transaction returns correct "usdValueExposureAsset".
        assertEq(usdValueExposureAsset, underlyingPMState.usdValue);

        // And: "exposureAssetToUnderlyingAssetsLast" is updated.
        bytes32 UnderlyingAssetKey =
            derivedPricingModule.getKeyFromAsset(assetState.underlyingAsset, assetState.underlyingAssetId);
        assertEq(
            derivedPricingModule.getExposureAssetToUnderlyingAssetsLast(assetKey, UnderlyingAssetKey),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "usdValueExposureAssetLast" is updated.
        (, uint256 usdValueExposureLast) = derivedPricingModule.getAssetToExposureLast(assetKey);
        assertEq(usdValueExposureLast, underlyingPMState.usdValue);

        // And: "usdExposureProtocol" is updated.
        assertEq(derivedPricingModule.usdExposureProtocol(), usdExposureProtocolExpected);
    }

    function testFuzz_Success_processWithdrawal_NegativeDeltaUsdExposure_NoUnderflow(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: No overflow on exposureAssetToUnderlyingAsset.
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint128).max);

        // And: delta "usdValueExposureAsset" is negative (test-case).
        vm.assume(assetState.usdValueExposureAssetLast > 0);
        underlyingPMState.usdValue = bound(underlyingPMState.usdValue, 0, assetState.usdValueExposureAssetLast - 1);

        // And: "usdExposureProtocol" does not underflow (test-case).
        protocolState.usdExposureProtocolLast = bound(
            protocolState.usdExposureProtocolLast,
            assetState.usdValueExposureAssetLast - underlyingPMState.usdValue,
            type(uint256).max
        );
        uint256 usdExposureProtocolExpected =
            protocolState.usdExposureProtocolLast - (assetState.usdValueExposureAssetLast - underlyingPMState.usdValue);

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, assetState.underlyingAssetId, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Pricing Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.exposureAssetToUnderlyingAssetsLast));
        bytes memory data = abi.encodeCall(
            mainRegistryExtension.getUsdValueExposureToUnderlyingAssetAfterWithdrawal,
            (
                assetState.underlyingAsset,
                assetState.underlyingAssetId,
                assetState.exposureAssetToUnderlyingAsset,
                deltaExposureAssetToUnderlyingAsset
            )
        );

        // When: "_processDeposit" is called.
        // Then: The Function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" on "MainRegistry" is called with correct parameters.
        vm.expectCall(address(mainRegistryExtension), data);
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdValueExposureAsset = derivedPricingModule.processWithdrawal(assetKey, exposureAsset);

        // Then: Transaction returns correct "usdValueExposureAsset".
        assertEq(usdValueExposureAsset, underlyingPMState.usdValue);

        // And: "exposureAssetToUnderlyingAssetsLast" is updated.
        bytes32 UnderlyingAssetKey =
            derivedPricingModule.getKeyFromAsset(assetState.underlyingAsset, assetState.underlyingAssetId);
        assertEq(
            derivedPricingModule.getExposureAssetToUnderlyingAssetsLast(assetKey, UnderlyingAssetKey),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "usdValueExposureAssetLast" is updated.
        (, uint256 usdValueExposureLast) = derivedPricingModule.getAssetToExposureLast(assetKey);
        assertEq(usdValueExposureLast, underlyingPMState.usdValue);

        // And: "usdExposureProtocol" is updated.
        assertEq(derivedPricingModule.usdExposureProtocol(), usdExposureProtocolExpected);
    }

    function testFuzz_Success_processWithdrawal_NegativeDeltaUsdExposure_Underflow(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: No overflow on exposureAssetToUnderlyingAsset.
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint128).max);

        // And: delta "usdValueExposureAsset" is negative (test-case).
        vm.assume(assetState.usdValueExposureAssetLast > 0);
        underlyingPMState.usdValue = bound(underlyingPMState.usdValue, 0, assetState.usdValueExposureAssetLast - 1);

        // And: "usdExposureProtocol" does underflow (test-case).
        protocolState.usdExposureProtocolLast = bound(
            protocolState.usdExposureProtocolLast, 0, assetState.usdValueExposureAssetLast - underlyingPMState.usdValue
        );

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, assetState.underlyingAssetId, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Pricing Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.exposureAssetToUnderlyingAssetsLast));
        bytes memory data = abi.encodeCall(
            mainRegistryExtension.getUsdValueExposureToUnderlyingAssetAfterWithdrawal,
            (
                assetState.underlyingAsset,
                assetState.underlyingAssetId,
                assetState.exposureAssetToUnderlyingAsset,
                deltaExposureAssetToUnderlyingAsset
            )
        );

        // When: "_processDeposit" is called.
        // Then: The Function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" on "MainRegistry" is called with correct parameters.
        vm.expectCall(address(mainRegistryExtension), data);
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdValueExposureAsset = derivedPricingModule.processWithdrawal(assetKey, exposureAsset);

        // Then: Transaction returns correct "usdValueExposureAsset".
        assertEq(usdValueExposureAsset, underlyingPMState.usdValue);

        // And: "exposureAssetToUnderlyingAssetsLast" is updated.
        bytes32 UnderlyingAssetKey =
            derivedPricingModule.getKeyFromAsset(assetState.underlyingAsset, assetState.underlyingAssetId);
        assertEq(
            derivedPricingModule.getExposureAssetToUnderlyingAssetsLast(assetKey, UnderlyingAssetKey),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "usdValueExposureAssetLast" is updated.
        (, uint256 usdValueExposureLast) = derivedPricingModule.getAssetToExposureLast(assetKey);
        assertEq(usdValueExposureLast, underlyingPMState.usdValue);

        // And: "usdExposureProtocol" is updated.
        assertEq(derivedPricingModule.usdExposureProtocol(), 0);
    }
}
