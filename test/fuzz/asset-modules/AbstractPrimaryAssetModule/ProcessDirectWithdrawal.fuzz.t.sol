/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryAssetModule_Fuzz_Test } from "./_AbstractPrimaryAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectWithdrawal" of contract "AbstractPrimaryAssetModule".
 */
contract ProcessDirectWithdrawal_AbstractPrimaryAssetModule_Fuzz_Test is AbstractPrimaryAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectWithdrawal_NonMainRegistry(
        PrimaryAssetModuleAssetState memory assetState,
        address unprivilegedAddress_,
        uint128 amount
    ) public {
        // Given "caller" is not the Main Registry.
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is withdrawn.
        // Then: The transaction reverts with "AAM: ONLY_MAIN_REGISTRY".
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("AAM: ONLY_MAIN_REGISTRY");
        assetModule.processDirectWithdrawal(assetState.creditor, assetState.asset, assetState.assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectWithdrawal_NoUnderflow(
        PrimaryAssetModuleAssetState memory assetState,
        uint256 amount
    ) public {
        // Given: exposure does not underflow after withdrawal (test-case).
        amount = bound(amount, 0, assetState.exposureAssetLast);

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is withdrawn.
        vm.prank(address(mainRegistryExtension));
        assetModule.processDirectWithdrawal(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);
        uint256 expectedExposure = assetState.exposureAssetLast - amount;

        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processDirectWithdrawal_WithUnderflow(
        PrimaryAssetModuleAssetState memory assetState,
        uint256 amount
    ) public {
        // Given: exposure does underflow after withdrawal (test-case).
        amount = bound(amount, assetState.exposureAssetLast, type(uint256).max);

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is withdrawn.
        vm.prank(address(mainRegistryExtension));
        assetModule.processDirectWithdrawal(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);

        assertEq(actualExposure, 0);
    }
}