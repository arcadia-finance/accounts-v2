/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractPrimaryAM_Fuzz_Test, AssetModule } from "./_AbstractPrimaryAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processIndirectWithdrawal" of contract "AbstractPrimaryAM".
 */
contract ProcessIndirectWithdrawal_AbstractPrimaryAM_Fuzz_Test is AbstractPrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectWithdrawal_NonRegistry(
        PrimaryAMAssetState memory assetState,
        address unprivilegedAddress_,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given "caller" is not the Registry.
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        // And: State is persisted.
        setPrimaryAMAssetState(assetState);

        // When: Asset is indirectly withdrawn.
        // Then: The transaction reverts with AssetModule.OnlyRegistry.selector.
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        assetModule.processIndirectWithdrawal(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectWithdrawal_OverExposure(
        PrimaryAMAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "exposureAsset" is bigger thantype(uint112).max (test-case).
        // And: "exposureAssetLast" does not overflow.
        deltaExposureUpperAssetToAsset = bound(
            deltaExposureUpperAssetToAsset, uint256(type(uint112).max) + 1 - assetState.exposureAssetLast, INT256_MAX
        );
        deltaExposureUpperAssetToAsset = bound(
            deltaExposureUpperAssetToAsset,
            uint256(type(uint112).max) + 1 - assetState.exposureAssetLast,
            type(uint256).max - assetState.exposureAssetLast
        );

        // And: State is persisted.
        setPrimaryAMAssetState(assetState);

        // When: Asset is indirectly withdrawn.
        // Then: The transaction reverts with "Overflow".
        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.Overflow.selector);
        assetModule.processIndirectWithdrawal(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            int256(deltaExposureUpperAssetToAsset)
        );
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectWithdrawal_positiveDelta(
        PrimaryAMAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "exposureAsset" is smaller or equal as "exposureAssetMax" (test-case).
        assetState.exposureAssetLast = uint112(bound(assetState.exposureAssetLast, 0, type(uint112).max - 1));
        deltaExposureUpperAssetToAsset =
            bound(deltaExposureUpperAssetToAsset, 1, type(uint112).max - assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast + deltaExposureUpperAssetToAsset;
        assetState.exposureAssetMax = uint112(bound(assetState.exposureAssetMax, expectedExposure, type(uint112).max));

        // And: State is persisted.
        setPrimaryAMAssetState(assetState);

        // When: Asset is indirectly withdrawn.
        vm.prank(address(registryExtension));
        uint256 usdExposureUpperAssetToAsset = assetModule.processIndirectWithdrawal(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            int256(deltaExposureUpperAssetToAsset)
        );

        // Then: Correct output variables are returned.
        assertEq(usdExposureUpperAssetToAsset, assetState.usdExposureUpperAssetToAsset);

        // And: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);
        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processIndirectWithdrawal_negativeDeltaWithAbsoluteValueSmallerThanExposure(
        PrimaryAMAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: deltaExposure is smaller or equal as assetState.exposureAssetLast.
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 0, assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast - deltaExposureUpperAssetToAsset;

        // And: State is persisted.
        setPrimaryAMAssetState(assetState);

        // When: Asset is indirectly withdrawn.
        vm.prank(address(registryExtension));
        uint256 usdExposureUpperAssetToAsset = assetModule.processIndirectWithdrawal(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        // Then: Correct output variables are returned.
        assertEq(usdExposureUpperAssetToAsset, assetState.usdExposureUpperAssetToAsset);

        // And: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);
        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processIndirectWithdrawal_negativeDeltaGreaterThanExposure(
        PrimaryAMAssetState memory assetState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: deltaExposure is bigger or equal as assetState.exposureAssetLast.
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, assetState.exposureAssetLast, INT256_MIN);

        // And: State is persisted.
        setPrimaryAMAssetState(assetState);

        // When: Asset is indirectly withdrawn.
        vm.prank(address(registryExtension));
        uint256 usdExposureUpperAssetToAsset = assetModule.processIndirectWithdrawal(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        // Then: Correct output variables are returned.
        assertEq(usdExposureUpperAssetToAsset, assetState.usdExposureUpperAssetToAsset);

        // And: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);
        assertEq(actualExposure, 0);
    }
}
