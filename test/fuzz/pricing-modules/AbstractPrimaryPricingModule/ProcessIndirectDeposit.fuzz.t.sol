/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "AbstractPrimaryPricingModule".
 */
contract ProcessIndirectDeposit_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonMainRegistry(
        PrimaryPricingModuleAssetState memory assetState,
        address unprivilegedAddress_,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given "caller" is not the Main Registry.
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        // And: State is persisted.
        setPrimaryPricingModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        // Then: The transaction reverts with "APM: ONLY_MAIN_REGISTRY".
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_OverExposure(
        PrimaryPricingModuleAssetState memory assetState,
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
        setPrimaryPricingModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        // Then: The transaction reverts with "APPM_PID: Exposure not in limits".
        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APPM_PID: Exposure not in limits");
        pricingModule.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            int256(deltaExposureUpperAssetToAsset)
        );
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit_positiveDelta(
        PrimaryPricingModuleAssetState memory assetState,
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
        setPrimaryPricingModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(mainRegistryExtension));
        (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) = pricingModule.processIndirectDeposit(
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
        (uint128 actualExposure,,,) = pricingModule.riskParams(assetState.creditor, assetKey);
        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processIndirectDeposit_negativeDeltaWithAbsoluteValueSmallerThanExposure(
        PrimaryPricingModuleAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: deltaExposure is smaller or equal as assetState.exposureAssetLast.
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 0, assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast - deltaExposureUpperAssetToAsset;

        // And: State is persisted.
        setPrimaryPricingModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(mainRegistryExtension));
        (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) = pricingModule.processIndirectDeposit(
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
        (uint128 actualExposure,,,) = pricingModule.riskParams(assetState.creditor, assetKey);

        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processIndirectDeposit_negativeDeltaGreaterThanExposure(
        PrimaryPricingModuleAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: deltaExposure is bigger or equal as assetState.exposureAssetLast.
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, assetState.exposureAssetLast, INT256_MIN);

        // And: State is persisted.
        setPrimaryPricingModuleAssetState(assetState);

        // When: Asset is indirectly deposited.
        vm.prank(address(mainRegistryExtension));
        (bool primaryFlag, uint256 usdExposureUpperAssetToAsset) = pricingModule.processIndirectDeposit(
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
        (uint128 actualExposure,,,) = pricingModule.riskParams(assetState.creditor, assetKey);
        assertEq(actualExposure, 0);
    }
}
