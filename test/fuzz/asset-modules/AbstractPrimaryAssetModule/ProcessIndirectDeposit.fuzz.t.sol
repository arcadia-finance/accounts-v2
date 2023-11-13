/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryAssetModule_Fuzz_Test } from "./_AbstractPrimaryAssetModule.fuzz.t.sol";

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
    function testFuzz_Revert_processIndirectDeposit_NonMainRegistry(
        PrimaryAssetModuleAssetState memory assetState,
        address unprivilegedAddress_,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given "caller" is not the Main Registry.
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        // Then: The transaction reverts with "AAM: ONLY_MAIN_REGISTRY".
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("AAM: ONLY_MAIN_REGISTRY");
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

        // And: "exposureAsset" is bigger than"exposureAssetMax" (test-case).
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, 0, expectedExposure - 1));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        // Then: The transaction reverts with "APAM_PID: Exposure not in limits".
        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APAM_PID: Exposure not in limits");
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
        // Given: "expectedExposure" is not 0.
        assetState.exposureAssetLast = uint128(bound(assetState.exposureAssetLast, 1, type(uint128).max));
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 0, assetState.exposureAssetLast - 1);
        uint256 expectedExposure = assetState.exposureAssetLast - deltaExposureUpperAssetToAsset;

        // And: "exposureAsset" is bigger than"exposureAssetMax" (test-case).
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, 0, expectedExposure - 1));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        // Then: The transaction reverts with "APAM_PID: Exposure not in limits".
        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APAM_PID: Exposure not in limits");
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
        // Given: "exposureAsset" is smaller or equal as "exposureAssetMax" (test-case).
        assetState.exposureAssetLast = uint128(bound(assetState.exposureAssetLast, 0, type(uint128).max - 1));
        deltaExposureUpperAssetToAsset =
            bound(deltaExposureUpperAssetToAsset, 1, type(uint128).max - assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast + deltaExposureUpperAssetToAsset;
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, expectedExposure, type(uint128).max));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(mainRegistryExtension));
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
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 0, assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast - deltaExposureUpperAssetToAsset;

        // And: "exposureAsset" is smaller or equal as "exposureAssetMax" (test-case).
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, expectedExposure, type(uint128).max));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(mainRegistryExtension));
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

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(mainRegistryExtension));
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
