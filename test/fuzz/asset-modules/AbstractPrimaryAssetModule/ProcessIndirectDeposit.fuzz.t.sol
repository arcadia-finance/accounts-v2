/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryAssetModule_Fuzz_Test, AssetModule } from "./_AbstractPrimaryAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "AbstractPrimaryAssetModule".
 */
contract ProcessIndirectDeposit_AbstractPrimaryAssetModule_Fuzz_Test is AbstractPrimaryAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonRegistry(
        PrimaryAssetModuleAssetState memory assetState,
        address unprivilegedAddress_,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given "caller" is not the Registry.
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        // Then: The transaction reverts with AssetModule.Only_Registry.selector.
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.Only_Registry.selector);
        assetModule.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_PositiveDelta_OverExposure(
        PrimaryAssetModuleAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "exposureAssetLast" does not overflow.
        assetState.exposureAssetLast = uint128(bound(assetState.exposureAssetLast, 0, type(uint128).max - 1));
        deltaExposureUpperAssetToAsset =
            bound(deltaExposureUpperAssetToAsset, 1, INT256_MAX - assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast + deltaExposureUpperAssetToAsset;

        // And: "exposureAsset" is bigger or equal as "exposureAssetMax" (test-case).
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, 0, expectedExposure));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        // Then: The transaction reverts with AssetModule.Exposure_Not_In_Limits.
        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.Exposure_Not_In_Limits.selector);
        assetModule.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            int256(deltaExposureUpperAssetToAsset)
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_NegativeDelta_OverExposure(
        PrimaryAssetModuleAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "exposureAsset" is bigger or equal as "exposureAssetMax" (test-case).
        uint256 expectedExposure;
        if (assetState.exposureAssetLast > deltaExposureUpperAssetToAsset) {
            expectedExposure = assetState.exposureAssetLast - deltaExposureUpperAssetToAsset;
        }
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, 0, expectedExposure));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        // Then: The transaction reverts with AssetModule.Exposure_Not_In_Limits.
        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.Exposure_Not_In_Limits.selector);
        assetModule.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit_PositiveDelta(
        PrimaryAssetModuleAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "exposureAsset" is strictly smaller as "exposureAssetMax" (test-case).
        assetState.exposureAssetLast = uint128(bound(assetState.exposureAssetLast, 0, type(uint128).max - 2));
        deltaExposureUpperAssetToAsset =
            bound(deltaExposureUpperAssetToAsset, 1, type(uint128).max - assetState.exposureAssetLast - 1);
        uint256 expectedExposure = assetState.exposureAssetLast + deltaExposureUpperAssetToAsset;
        assetState.exposureAssetMax =
            uint128(bound(assetState.exposureAssetMax, expectedExposure + 1, type(uint128).max));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(registryExtension));
        (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) = assetModule.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            int256(deltaExposureUpperAssetToAsset)
        );

        // Then: Correct output variables are returned.
        assertTrue(primaryFlag);
        assertEq(usdExposureUpperAssetToAsset, assetState.usdExposureUpperAssetToAsset);

        // And: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);
        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processIndirectDeposit_NegativeDelta_DeltaSmallerThanExposureLast(
        PrimaryAssetModuleAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: deltaExposure is smaller or equal as assetState.exposureAssetLast.
        assetState.exposureAssetLast = uint128(bound(assetState.exposureAssetLast, 0, type(uint128).max - 1));
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 0, assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast - deltaExposureUpperAssetToAsset;

        // And: "exposureAsset" is strictly smaller as "exposureAssetMax" (test-case).
        assetState.exposureAssetMax =
            uint128(bound(assetState.exposureAssetMax, expectedExposure + 1, type(uint128).max));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(registryExtension));
        (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) = assetModule.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        // Then: Correct output variables are returned.
        assertTrue(primaryFlag);
        assertEq(usdExposureUpperAssetToAsset, assetState.usdExposureUpperAssetToAsset);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);

        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processIndirectDeposit_NegativeDelta_DeltaGreaterThanExposureLast(
        PrimaryAssetModuleAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: deltaExposure is bigger or equal as assetState.exposureAssetLast.
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, assetState.exposureAssetLast, INT256_MIN);

        // And: "exposureAsset" is strictly smaller as "exposureAssetMax" (test-case).
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, 1, type(uint128).max));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(registryExtension));
        (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) = assetModule.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        // Then: Correct output variables are returned.
        assertTrue(primaryFlag);
        assertEq(usdExposureUpperAssetToAsset, assetState.usdExposureUpperAssetToAsset);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);
        assertEq(actualExposure, 0);
    }
}
