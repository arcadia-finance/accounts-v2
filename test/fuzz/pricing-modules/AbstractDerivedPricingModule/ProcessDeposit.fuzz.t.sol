/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_processDeposit" of contract "AbstractDerivedPricingModule".
 */
contract ProcessDeposit_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDeposit_PositiveDeltaUsdExposure_OverExposure(
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
        protocolState.usdExposureProtocolLast = uint128(
            bound(
                protocolState.usdExposureProtocolLast,
                assetState.usdValueExposureAssetLast,
                type(uint128).max - (underlyingPMState.usdValue - assetState.usdValueExposureAssetLast)
            )
        );
        uint256 usdExposureProtocolExpected =
            protocolState.usdExposureProtocolLast + (underlyingPMState.usdValue - assetState.usdValueExposureAssetLast);

        // And: exposure exceeds max exposure.
        vm.assume(usdExposureProtocolExpected > 0);
        protocolState.maxUsdExposureProtocol =
            uint128(bound(protocolState.maxUsdExposureProtocol, 0, usdExposureProtocolExpected - 1));

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState, assetState.creditor);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState, underlyingPMState);

        // When: "_processDeposit" is called.
        // Then: The transaction reverts with "ADPM_PD: Exposure not in limits".
        bytes32 assetKey = derivedPricingModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        vm.expectRevert("ADPM_PD: Exposure not in limits");
        derivedPricingModule.processDeposit(assetState.creditor, assetKey, exposureAsset);
    }

    function testFuzz_Success_processDeposit_PositiveDeltaUsdExposure_UnderExposure(
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
        protocolState.usdExposureProtocolLast = uint128(
            bound(
                protocolState.usdExposureProtocolLast,
                assetState.usdValueExposureAssetLast,
                type(uint128).max - (underlyingPMState.usdValue - assetState.usdValueExposureAssetLast)
            )
        );
        uint256 usdExposureProtocolExpected =
            protocolState.usdExposureProtocolLast + (underlyingPMState.usdValue - assetState.usdValueExposureAssetLast);

        // And: exposure does not exceeds max exposure.
        protocolState.maxUsdExposureProtocol =
            uint128(bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected, type(uint128).max));

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState, assetState.creditor);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Pricing Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.exposureAssetToUnderlyingAssetsLast));
        bytes memory data = abi.encodeCall(
            mainRegistryExtension.getUsdValueExposureToUnderlyingAssetAfterDeposit,
            (
                assetState.creditor,
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
        uint256 usdValueExposureAsset =
            derivedPricingModule.processDeposit(assetState.creditor, assetKey, exposureAsset);

        // And: Transaction returns correct "usdValueExposureAsset".
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
        (uint128 usdExposureProtocolActual,,) = derivedPricingModule.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, usdExposureProtocolExpected);
    }

    function testFuzz_Success_processDeposit_NegativeDeltaUsdExposure_NoUnderflow(
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
        protocolState.usdExposureProtocolLast = uint128(
            bound(
                protocolState.usdExposureProtocolLast,
                assetState.usdValueExposureAssetLast - underlyingPMState.usdValue,
                type(uint128).max
            )
        );
        uint256 usdExposureProtocolExpected =
            protocolState.usdExposureProtocolLast - (assetState.usdValueExposureAssetLast - underlyingPMState.usdValue);

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState, assetState.creditor);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Pricing Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.exposureAssetToUnderlyingAssetsLast));
        bytes memory data = abi.encodeCall(
            mainRegistryExtension.getUsdValueExposureToUnderlyingAssetAfterDeposit,
            (
                assetState.creditor,
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
        uint256 usdValueExposureAsset =
            derivedPricingModule.processDeposit(assetState.creditor, assetKey, exposureAsset);

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
        (uint128 usdExposureProtocolActual,,) = derivedPricingModule.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, usdExposureProtocolExpected);
    }

    function testFuzz_Success_processDeposit_NegativeDeltaUsdExposure_Underflow(
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
        protocolState.usdExposureProtocolLast = uint128(
            bound(
                protocolState.usdExposureProtocolLast,
                0,
                assetState.usdValueExposureAssetLast - underlyingPMState.usdValue
            )
        );

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState, assetState.creditor);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Pricing Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.exposureAssetToUnderlyingAssetsLast));
        bytes memory data = abi.encodeCall(
            mainRegistryExtension.getUsdValueExposureToUnderlyingAssetAfterDeposit,
            (
                assetState.creditor,
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
        uint256 usdValueExposureAsset =
            derivedPricingModule.processDeposit(assetState.creditor, assetKey, exposureAsset);

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
        (uint128 usdExposureProtocolActual,,) = derivedPricingModule.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, 0);
    }
}
