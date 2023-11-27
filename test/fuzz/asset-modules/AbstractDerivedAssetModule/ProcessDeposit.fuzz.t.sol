/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractDerivedAssetModule_Fuzz_Test, AssetModule } from "./_AbstractDerivedAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_processDeposit" of contract "AbstractDerivedAssetModule".
 */
contract ProcessDeposit_AbstractDerivedAssetModule_Fuzz_Test is AbstractDerivedAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDeposit_PositiveDeltaUsdExposure_OverExposure(
        DerivedAssetModuleProtocolState memory protocolState,
        DerivedAssetModuleAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: "exposure" of underlyingAsset is strictly smaller than its "maxExposure".
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint112).max - 1);

        // And: delta "usdExposureAsset" is positive (test-case).
        underlyingPMState.usdValue =
            bound(underlyingPMState.usdValue, assetState.lastUsdExposureAsset, type(uint112).max);

        // And: "usdExposureProtocol" does not overflow (unrealistically big).
        protocolState.lastUsdExposureProtocol = uint112(
            bound(
                protocolState.lastUsdExposureProtocol,
                assetState.lastUsdExposureAsset,
                type(uint112).max - (underlyingPMState.usdValue - assetState.lastUsdExposureAsset)
            )
        );
        uint256 usdExposureProtocolExpected =
            protocolState.lastUsdExposureProtocol + (underlyingPMState.usdValue - assetState.lastUsdExposureAsset);

        // And: exposure exceeds max exposure.
        vm.assume(usdExposureProtocolExpected > 0);
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, 0, usdExposureProtocolExpected - 1));

        // And: State is persisted.
        setDerivedAssetModuleProtocolState(protocolState, assetState.creditor);
        setDerivedAssetModuleAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "_processDeposit" is called.
        // Then: The transaction reverts with AssetModule.ExposureNotInLimits.selector.
        bytes32 assetKey = derivedAssetModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        derivedAssetModule.processDeposit(assetState.creditor, assetKey, exposureAsset);
    }

    function testFuzz_Revert_processDeposit_NegativeDeltaUsdExposure_OverExposure(
        DerivedAssetModuleProtocolState memory protocolState,
        DerivedAssetModuleAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: "exposure" of underlyingAsset is strictly smaller than its "maxExposure".
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint112).max - 1);

        // And: delta "usdExposureAsset" is negative (test-case).
        underlyingPMState.usdValue = bound(underlyingPMState.usdValue, 0, assetState.lastUsdExposureAsset);

        // And: "exposure" is equal or bigger than "maxExposure".
        uint256 usdExposureProtocolExpected;
        if (protocolState.lastUsdExposureProtocol > assetState.lastUsdExposureAsset - underlyingPMState.usdValue) {
            usdExposureProtocolExpected =
                protocolState.lastUsdExposureProtocol - (assetState.lastUsdExposureAsset - underlyingPMState.usdValue);
        }
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, 0, usdExposureProtocolExpected));

        // And: State is persisted.
        setDerivedAssetModuleProtocolState(protocolState, assetState.creditor);
        setDerivedAssetModuleAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "_processDeposit" is called.
        // Then: The transaction reverts with AssetModule.ExposureNotInLimits.selector.
        bytes32 assetKey = derivedAssetModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        derivedAssetModule.processDeposit(assetState.creditor, assetKey, exposureAsset);
    }

    function testFuzz_Success_processDeposit_PositiveDeltaUsdExposure_UnderExposure(
        DerivedAssetModuleProtocolState memory protocolState,
        DerivedAssetModuleAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: "exposure" of underlyingAsset is strictly smaller than its "maxExposure".
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint112).max - 1);

        // And: delta "usdExposureAsset" is positive (test-case).
        underlyingPMState.usdValue =
            bound(underlyingPMState.usdValue, assetState.lastUsdExposureAsset, type(uint112).max);

        // And: "usdExposureProtocol" does not overflow (unrealistically big).
        protocolState.lastUsdExposureProtocol = uint112(
            bound(
                protocolState.lastUsdExposureProtocol,
                assetState.lastUsdExposureAsset,
                type(uint112).max - (underlyingPMState.usdValue - assetState.lastUsdExposureAsset)
            )
        );
        uint256 usdExposureProtocolExpected =
            protocolState.lastUsdExposureProtocol + (underlyingPMState.usdValue - assetState.lastUsdExposureAsset);

        // And: "exposure" is strictly smaller than "maxExposure" (test-case).
        vm.assume(usdExposureProtocolExpected < type(uint112).max);
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected + 1, type(uint112).max));

        // And: State is persisted.
        setDerivedAssetModuleProtocolState(protocolState, assetState.creditor);
        setDerivedAssetModuleAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Asset Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.lastExposureAssetToUnderlyingAsset));
        bytes memory data = abi.encodeCall(
            registryExtension.getUsdValueExposureToUnderlyingAssetAfterDeposit,
            (
                assetState.creditor,
                assetState.underlyingAsset,
                assetState.underlyingAssetId,
                assetState.exposureAssetToUnderlyingAsset,
                deltaExposureAssetToUnderlyingAsset
            )
        );

        // When: "_processDeposit" is called.
        // Then: The Function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" on "Registry" is called with correct parameters.
        vm.expectCall(address(registryExtension), data);
        bytes32 assetKey = derivedAssetModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdExposureAsset = derivedAssetModule.processDeposit(assetState.creditor, assetKey, exposureAsset);

        // And: Transaction returns correct "usdExposureAsset".
        assertEq(usdExposureAsset, underlyingPMState.usdValue);

        // And: "lastExposureAssetToUnderlyingAsset" is updated.
        bytes32 UnderlyingAssetKey =
            derivedAssetModule.getKeyFromAsset(assetState.underlyingAsset, assetState.underlyingAssetId);
        assertEq(
            derivedAssetModule.getExposureAssetToUnderlyingAssetsLast(assetState.creditor, assetKey, UnderlyingAssetKey),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "lastUsdExposureAsset" is updated.
        (, uint256 lastUsdExposureAsset) = derivedAssetModule.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(lastUsdExposureAsset, underlyingPMState.usdValue);

        // And: "usdExposureProtocol" is updated.
        (uint128 usdExposureProtocolActual,,) = derivedAssetModule.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, usdExposureProtocolExpected);
    }

    function testFuzz_Success_processDeposit_NegativeDeltaUsdExposure_NoUnderflow(
        DerivedAssetModuleProtocolState memory protocolState,
        DerivedAssetModuleAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: "exposure" of underlyingAsset is strictly smaller than its "maxExposure".
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint112).max - 1);

        // And: delta "usdExposureAsset" is negative (test-case).
        assetState.lastUsdExposureAsset = uint112(bound(assetState.lastUsdExposureAsset, 1, type(uint112).max));
        underlyingPMState.usdValue = bound(underlyingPMState.usdValue, 0, assetState.lastUsdExposureAsset - 1);

        // And: "usdExposureProtocol" does not underflow (test-case).
        protocolState.lastUsdExposureProtocol = uint112(
            bound(
                protocolState.lastUsdExposureProtocol,
                assetState.lastUsdExposureAsset - underlyingPMState.usdValue,
                type(uint112).max
            )
        );
        uint256 usdExposureProtocolExpected =
            protocolState.lastUsdExposureProtocol - (assetState.lastUsdExposureAsset - underlyingPMState.usdValue);

        // And: "exposure" is strictly smaller than "maxExposure" (test-case).
        vm.assume(usdExposureProtocolExpected < type(uint112).max);
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected + 1, type(uint112).max));

        // And: State is persisted.
        setDerivedAssetModuleProtocolState(protocolState, assetState.creditor);
        setDerivedAssetModuleAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Asset Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.lastExposureAssetToUnderlyingAsset));
        bytes memory data = abi.encodeCall(
            registryExtension.getUsdValueExposureToUnderlyingAssetAfterDeposit,
            (
                assetState.creditor,
                assetState.underlyingAsset,
                assetState.underlyingAssetId,
                assetState.exposureAssetToUnderlyingAsset,
                deltaExposureAssetToUnderlyingAsset
            )
        );

        // When: "_processDeposit" is called.
        // Then: The Function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" on "Registry" is called with correct parameters.
        vm.expectCall(address(registryExtension), data);
        bytes32 assetKey = derivedAssetModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdExposureAsset = derivedAssetModule.processDeposit(assetState.creditor, assetKey, exposureAsset);

        // Then: Transaction returns correct "usdExposureAsset".
        assertEq(usdExposureAsset, underlyingPMState.usdValue);

        // And: "lastExposureAssetToUnderlyingAsset" is updated.
        bytes32 UnderlyingAssetKey =
            derivedAssetModule.getKeyFromAsset(assetState.underlyingAsset, assetState.underlyingAssetId);
        assertEq(
            derivedAssetModule.getExposureAssetToUnderlyingAssetsLast(assetState.creditor, assetKey, UnderlyingAssetKey),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "lastUsdExposureAsset" is updated.
        (, uint256 lastUsdExposureAsset) = derivedAssetModule.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(lastUsdExposureAsset, underlyingPMState.usdValue);

        // And: "usdExposureProtocol" is updated.
        (uint128 usdExposureProtocolActual,,) = derivedAssetModule.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, usdExposureProtocolExpected);
    }

    function testFuzz_Success_processDeposit_NegativeDeltaUsdExposure_Underflow(
        DerivedAssetModuleProtocolState memory protocolState,
        DerivedAssetModuleAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: "exposure" of underlyingAsset is strictly smaller than its "maxExposure".
        assetState.exposureAssetToUnderlyingAsset =
            bound(assetState.exposureAssetToUnderlyingAsset, 0, type(uint112).max - 1);

        // And: delta "usdExposureAsset" is negative (test-case).
        vm.assume(assetState.lastUsdExposureAsset > 0);
        underlyingPMState.usdValue = bound(underlyingPMState.usdValue, 0, assetState.lastUsdExposureAsset - 1);

        // And: "usdExposureProtocol" does underflow (test-case).
        protocolState.lastUsdExposureProtocol = uint112(
            bound(
                protocolState.lastUsdExposureProtocol, 0, assetState.lastUsdExposureAsset - underlyingPMState.usdValue
            )
        );

        // And: "exposure" is strictly smaller than "maxExposure" (test-case).
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, 1, type(uint112).max));

        // And: State is persisted.
        setDerivedAssetModuleProtocolState(protocolState, assetState.creditor);
        setDerivedAssetModuleAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Asset Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.lastExposureAssetToUnderlyingAsset));
        bytes memory data = abi.encodeCall(
            registryExtension.getUsdValueExposureToUnderlyingAssetAfterDeposit,
            (
                assetState.creditor,
                assetState.underlyingAsset,
                assetState.underlyingAssetId,
                assetState.exposureAssetToUnderlyingAsset,
                deltaExposureAssetToUnderlyingAsset
            )
        );

        // When: "_processDeposit" is called.
        // Then: The Function "getUsdValueExposureToUnderlyingAssetAfterWithdrawal" on "Registry" is called with correct parameters.
        vm.expectCall(address(registryExtension), data);
        bytes32 assetKey = derivedAssetModule.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdExposureAsset = derivedAssetModule.processDeposit(assetState.creditor, assetKey, exposureAsset);

        // Then: Transaction returns correct "usdExposureAsset".
        assertEq(usdExposureAsset, underlyingPMState.usdValue);

        // And: "lastExposureAssetToUnderlyingAsset" is updated.
        bytes32 UnderlyingAssetKey =
            derivedAssetModule.getKeyFromAsset(assetState.underlyingAsset, assetState.underlyingAssetId);
        assertEq(
            derivedAssetModule.getExposureAssetToUnderlyingAssetsLast(assetState.creditor, assetKey, UnderlyingAssetKey),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "lastUsdExposureAsset" is updated.
        (, uint256 lastUsdExposureAsset) = derivedAssetModule.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(lastUsdExposureAsset, underlyingPMState.usdValue);

        // And: "usdExposureProtocol" is updated.
        (uint128 usdExposureProtocolActual,,) = derivedAssetModule.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, 0);
    }
}
