/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryAssetModule_Fuzz_Test, AssetModule } from "./_AbstractPrimaryAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "AbstractPrimaryAssetModule".
 */
contract ProcessDirectDeposit_AbstractPrimaryAssetModule_Fuzz_Test is AbstractPrimaryAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonRegistry(
        PrimaryAssetModuleAssetState memory assetState,
        address unprivilegedAddress_,
        uint256 amount
    ) public {
        // Given "caller" is not the Registry.
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is deposited.
        // Then: The transaction reverts with AssetModule.Only_Registry.selector.
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.Only_Registry.selector);
        assetModule.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_OverExposure(
        PrimaryAssetModuleAssetState memory assetState,
        uint256 amount
    ) public {
        // Given: "exposureAssetLast" does not overflow.
        amount = bound(amount, 0, type(uint256).max - assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast + amount;

        // And: "exposureAsset" is bigger or equal as "exposureAssetMax" (test-case).
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, 0, expectedExposure));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is deposited.
        // Then: The transaction reverts with AssetModule.Exposure_Not_In_Limits.selector.
        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.Exposure_Not_In_Limits.selector);
        assetModule.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(PrimaryAssetModuleAssetState memory assetState, uint256 amount)
        public
    {
        // Given: "exposureAsset" is strictly smaller than "exposureAssetMax" (test-case).
        assetState.exposureAssetLast = uint128(bound(assetState.exposureAssetLast, 0, type(uint128).max - 1));
        amount = bound(amount, 0, type(uint128).max - assetState.exposureAssetLast - 1);
        uint256 expectedExposure = assetState.exposureAssetLast + amount;
        assetState.exposureAssetMax =
            uint128(bound(assetState.exposureAssetMax, expectedExposure + 1, type(uint128).max));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is deposited.
        vm.prank(address(registryExtension));
        uint256 assetType =
            assetModule.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, amount);

        assertEq(assetType, 0);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);

        assertEq(actualExposure, expectedExposure);
    }
}
