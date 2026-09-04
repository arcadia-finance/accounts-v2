/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractDerivedAM_Fuzz_Test } from "./_AbstractDerivedAM.fuzz.t.sol";
import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { AssetModule } from "../../../../src/asset-modules/abstracts/AbstractAM.sol";

/**
 * @notice Fuzz tests for the function "_processDeposit" of contract "AbstractDerivedAM".
 */
// forge-lint: disable-next-item(mixed-case-variable,unsafe-typecast)
contract ProcessDeposit_AbstractDerivedAM_Fuzz_Test is AbstractDerivedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDeposit_PositiveDeltaUsdExposure_OverExposure(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: delta "usdExposureAsset" is positive (test-case).
        uint256 usdValue = usdExposureToUnderlyingAsset(assetState, underlyingPMState);
        assetState.lastUsdExposureAsset = uint112(bound(assetState.lastUsdExposureAsset, 0, usdValue));

        // And: "usdExposureProtocol" does not overflow (unrealistically big).
        protocolState.lastUsdExposureProtocol = uint112(
            bound(
                protocolState.lastUsdExposureProtocol,
                assetState.lastUsdExposureAsset == 0 ? 1 : assetState.lastUsdExposureAsset,
                type(uint112).max - (usdValue - assetState.lastUsdExposureAsset)
            )
        );
        uint256 usdExposureProtocolExpected =
            protocolState.lastUsdExposureProtocol + (usdValue - assetState.lastUsdExposureAsset);

        // And: exposure exceeds max exposure.
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, 0, usdExposureProtocolExpected - 1));

        // And: State is persisted.
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "_processDeposit" is called.
        // Then: The transaction reverts with AssetModule.ExposureNotInLimits.selector.
        bytes32 assetKey = derivedAM.getKeyFromAsset(assetState.asset, assetState.assetId);
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        derivedAM.processDeposit(assetState.creditor, assetKey, exposureAsset);
    }

    function testFuzz_Revert_processDeposit_NegativeDeltaUsdExposure_OverExposure(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: delta "usdExposureAsset" is negative (test-case).
        uint256 usdValue = usdExposureToUnderlyingAsset(assetState, underlyingPMState);
        assetState.lastUsdExposureAsset = uint112(bound(assetState.lastUsdExposureAsset, usdValue, type(uint112).max));

        // And: "exposure" is equal or bigger than "maxExposure".
        uint256 usdExposureProtocolExpected;
        if (protocolState.lastUsdExposureProtocol > assetState.lastUsdExposureAsset - usdValue) {
            usdExposureProtocolExpected =
                protocolState.lastUsdExposureProtocol - (assetState.lastUsdExposureAsset - usdValue);
        }
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, 0, usdExposureProtocolExpected));

        // And: State is persisted.
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "_processDeposit" is called.
        // Then: The transaction reverts with AssetModule.ExposureNotInLimits.selector.
        bytes32 assetKey = derivedAM.getKeyFromAsset(assetState.asset, assetState.assetId);
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        derivedAM.processDeposit(assetState.creditor, assetKey, exposureAsset);
    }

    function testFuzz_Success_processDeposit_PositiveDeltaUsdExposure_UnderExposure(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: delta "usdExposureAsset" is positive (test-case).
        uint256 usdValue = usdExposureToUnderlyingAsset(assetState, underlyingPMState);
        assetState.lastUsdExposureAsset = uint112(bound(assetState.lastUsdExposureAsset, 0, usdValue));

        // And: "usdExposureProtocol" does not overflow (unrealistically big).
        protocolState.lastUsdExposureProtocol = uint112(
            bound(
                protocolState.lastUsdExposureProtocol,
                assetState.lastUsdExposureAsset,
                type(uint112).max - (usdValue - assetState.lastUsdExposureAsset) - 1
            )
        );
        uint256 usdExposureProtocolExpected =
            protocolState.lastUsdExposureProtocol + (usdValue - assetState.lastUsdExposureAsset);
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected + 1, type(uint112).max));

        // And: State is persisted.
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Asset Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.lastExposureAssetToUnderlyingAsset));
        bytes memory data = abi.encodeCall(
            registry.getUsdValueExposureToUnderlyingAssetAfterDeposit,
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
        vm.expectCall(address(registry), data);
        bytes32 assetKey = derivedAM.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdExposureAsset = derivedAM.processDeposit(assetState.creditor, assetKey, exposureAsset);

        // And: Transaction returns correct "usdExposureAsset".
        assertEq(usdExposureAsset, usdValue);

        // And: "lastExposureAssetToUnderlyingAsset" is updated.
        assertEq(
            derivedAM.getExposureAssetToUnderlyingAssetsLast(assetState.creditor, assetKey, 0),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "lastUsdExposureAsset" is updated.
        (, uint256 lastUsdExposureAsset) = derivedAM.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(lastUsdExposureAsset, usdValue);

        // And: "usdExposureProtocol" is updated.
        (uint128 usdExposureProtocolActual,,) = derivedAM.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, usdExposureProtocolExpected);
    }

    function testFuzz_Success_processDeposit_NegativeDeltaUsdExposure_NoUnderflow(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: delta "usdExposureAsset" is negative (test-case).
        uint256 usdValue = usdExposureToUnderlyingAsset(assetState, underlyingPMState);
        assetState.lastUsdExposureAsset =
            uint112(bound(assetState.lastUsdExposureAsset, usdValue + 1, type(uint112).max));

        // And: "usdExposureProtocol" does not underflow (test-case).
        protocolState.lastUsdExposureProtocol = uint112(
            bound(protocolState.lastUsdExposureProtocol, assetState.lastUsdExposureAsset - usdValue, type(uint112).max)
        );
        uint256 usdExposureProtocolExpected =
            protocolState.lastUsdExposureProtocol - (assetState.lastUsdExposureAsset - usdValue);

        // And: "exposure" is strictly smaller than "maxExposure" (test-case).
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, usdExposureProtocolExpected + 1, type(uint112).max));

        // And: State is persisted.
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Asset Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.lastExposureAssetToUnderlyingAsset));
        bytes memory data = abi.encodeCall(
            registry.getUsdValueExposureToUnderlyingAssetAfterDeposit,
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
        vm.expectCall(address(registry), data);
        bytes32 assetKey = derivedAM.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdExposureAsset = derivedAM.processDeposit(assetState.creditor, assetKey, exposureAsset);

        // Then: Transaction returns correct "usdExposureAsset".
        assertEq(usdExposureAsset, usdValue);

        // And: "lastExposureAssetToUnderlyingAsset" is updated.
        assertEq(
            derivedAM.getExposureAssetToUnderlyingAssetsLast(assetState.creditor, assetKey, 0),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "lastUsdExposureAsset" is updated.
        (, uint256 lastUsdExposureAsset) = derivedAM.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(lastUsdExposureAsset, usdValue);

        // And: "usdExposureProtocol" is updated.
        (uint128 usdExposureProtocolActual,,) = derivedAM.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, usdExposureProtocolExpected);
    }

    function testFuzz_Success_processDeposit_NegativeDeltaUsdExposure_Underflow(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureAsset
    ) public {
        // Given: valid initial state.
        (protocolState, assetState, underlyingPMState) = givenValidState(protocolState, assetState, underlyingPMState);

        // And: delta "usdExposureAsset" is negative (test-case).
        uint256 usdValue = usdExposureToUnderlyingAsset(assetState, underlyingPMState);
        assetState.lastUsdExposureAsset =
            uint112(bound(assetState.lastUsdExposureAsset, usdValue + 1, type(uint112).max));

        // And: "usdExposureProtocol" does underflow (test-case).
        protocolState.lastUsdExposureProtocol =
            uint112(bound(protocolState.lastUsdExposureProtocol, 0, assetState.lastUsdExposureAsset - usdValue));

        // And: "exposure" is strictly smaller than "maxExposure" (test-case).
        protocolState.maxUsdExposureProtocol =
            uint112(bound(protocolState.maxUsdExposureProtocol, 1, type(uint112).max));

        // And: State is persisted.
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // And: Underlying Asset is properly added to an underlying Asset Module.
        int256 deltaExposureAssetToUnderlyingAsset = int256(assetState.exposureAssetToUnderlyingAsset)
            - int256(uint256(assetState.lastExposureAssetToUnderlyingAsset));
        bytes memory data = abi.encodeCall(
            registry.getUsdValueExposureToUnderlyingAssetAfterDeposit,
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
        vm.expectCall(address(registry), data);
        bytes32 assetKey = derivedAM.getKeyFromAsset(assetState.asset, assetState.assetId);
        uint256 usdExposureAsset = derivedAM.processDeposit(assetState.creditor, assetKey, exposureAsset);

        // Then: Transaction returns correct "usdExposureAsset".
        assertEq(usdExposureAsset, usdValue);

        // And: "lastExposureAssetToUnderlyingAsset" is updated.
        assertEq(
            derivedAM.getExposureAssetToUnderlyingAssetsLast(assetState.creditor, assetKey, 0),
            assetState.exposureAssetToUnderlyingAsset
        );

        // And: "lastUsdExposureAsset" is updated.
        (, uint256 lastUsdExposureAsset) = derivedAM.getAssetExposureLast(assetState.creditor, assetKey);
        assertEq(lastUsdExposureAsset, usdValue);

        // And: "usdExposureProtocol" is updated.
        (uint128 usdExposureProtocolActual,,) = derivedAM.riskParams(assetState.creditor);
        assertEq(usdExposureProtocolActual, 0);
    }

    function testFuzz_Success_processDeposit_DuplicateUnderlyingAssets(
        address creditor,
        address asset,
        uint256 assetId,
        address underlyingAssetA,
        address underlyingAssetB,
        uint256 amount0,
        uint256 amount1,
        uint256 rewards
    ) public {
        // Given: Two distinct underlying assets.
        vm.assume(underlyingAssetA != underlyingAssetB);

        // And: id's are smaller or equal to type(uint96).max.
        assetId = bound(assetId, 0, type(uint96).max);

        // And: "exposure" of the underlying assets is strictly smaller than their "maxExposure".
        amount0 = bound(amount0, 0, type(uint112).max - 1);
        rewards = bound(rewards, 0, type(uint112).max - 1 - amount0);
        amount1 = bound(amount1, 0, type(uint112).max - 1);

        // And: The asset has underlying assets [A, B, A] (the reward token equals one of the pool tokens).
        address[] memory underlyingAssets = new address[](3);
        underlyingAssets[0] = underlyingAssetA;
        underlyingAssets[1] = underlyingAssetB;
        underlyingAssets[2] = underlyingAssetA;
        uint256[] memory underlyingAssetIds = new uint256[](3);
        derivedAM.addAsset(asset, assetId, underlyingAssets, underlyingAssetIds);

        uint256[] memory underlyingAssetsAmounts = new uint256[](3);
        underlyingAssetsAmounts[0] = amount0;
        underlyingAssetsAmounts[1] = amount1;
        underlyingAssetsAmounts[2] = rewards;
        derivedAM.setUnderlyingAssetsAmounts(underlyingAssetsAmounts);

        // And: State is persisted.
        derivedAM.setUsdExposureProtocol(creditor, type(uint112).max, 0);
        registry.setAssetModule(underlyingAssetA, address(primaryAM));
        registry.setAssetModule(underlyingAssetB, address(primaryAM));
        primaryAM.setExposure(creditor, underlyingAssetA, 0, 0, type(uint112).max);
        primaryAM.setExposure(creditor, underlyingAssetB, 0, 0, type(uint112).max);

        // And: Both underlying assets are priced.
        {
            addMockedOracle(PRIMARY_AM_ORACLE_ID, 0, bytes16("A"), bytes16("USD"), true);
            uint80[] memory oracleIds = new uint80[](1);
            oracleIds[0] = uint80(PRIMARY_AM_ORACLE_ID);
            bool[] memory baseToQuoteAsset = new bool[](1);
            baseToQuoteAsset[0] = true;
            bytes32 sequence = BitPackingLib.pack(baseToQuoteAsset, oracleIds);
            primaryAM.setAssetInformation(underlyingAssetA, 0, 1, sequence);
            primaryAM.setAssetInformation(underlyingAssetB, 0, 1, sequence);
        }

        // When: "_processDeposit" is called.
        bytes32 assetKey = derivedAM.getKeyFromAsset(asset, assetId);
        derivedAM.processDeposit(creditor, assetKey, 1);

        // Then: The exposure to the duplicated underlying asset is the sum of both occurrences.
        (uint112 lastExposureA,,,) = primaryAM.riskParams(creditor, derivedAM.getKeyFromAsset(underlyingAssetA, 0));
        assertEq(lastExposureA, amount0 + rewards);

        // And: The exposure to the non-duplicated underlying asset is correct.
        (uint112 lastExposureB,,,) = primaryAM.riskParams(creditor, derivedAM.getKeyFromAsset(underlyingAssetB, 0));
        assertEq(lastExposureB, amount1);
    }
}
