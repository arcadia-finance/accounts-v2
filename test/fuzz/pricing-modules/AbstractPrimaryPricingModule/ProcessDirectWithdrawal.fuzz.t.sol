/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryPricingModule_Fuzz_Test } from "./_AbstractPrimaryPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectWithdrawal" of contract "AbstractPrimaryPricingModule".
 */
contract ProcessDirectWithdrawal_AbstractPrimaryPricingModule_Fuzz_Test is AbstractPrimaryPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectWithdrawal_NonMainRegistry(
        PrimaryPricingModuleAssetState memory assetState,
        address unprivilegedAddress_,
        uint128 amount
    ) public {
        // Given "caller" is not the Main Registry.
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        // And: State is persisted.
        setPrimaryPricingModuleAssetState(assetState);

        // When: "amount" is withdrawn.
        // Then: The transaction reverts with "APM: ONLY_MAIN_REGISTRY".
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        pricingModule.processDirectWithdrawal(assetState.creditor, assetState.asset, assetState.assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectWithdrawal_NoUnderflow(
        PrimaryPricingModuleAssetState memory assetState,
        uint256 amount
    ) public {
        // Given: exposure does not underflow after withdrawal (test-case).
        amount = bound(amount, 0, assetState.exposureAssetLast);

        // And: State is persisted.
        setPrimaryPricingModuleAssetState(assetState);

        // When: "amount" is withdrawn.
        vm.prank(address(mainRegistryExtension));
        pricingModule.processDirectWithdrawal(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = pricingModule.riskParams(assetState.creditor, assetKey);
        uint256 expectedExposure = assetState.exposureAssetLast - amount;

        assertEq(actualExposure, expectedExposure);
    }

    function testFuzz_Success_processDirectWithdrawal_WithUnderflow(
        PrimaryPricingModuleAssetState memory assetState,
        uint256 amount
    ) public {
        // Given: exposure does underflow after withdrawal (test-case).
        amount = bound(amount, assetState.exposureAssetLast, type(uint256).max);

        // And: State is persisted.
        setPrimaryPricingModuleAssetState(assetState);

        // When: "amount" is withdrawn.
        vm.prank(address(mainRegistryExtension));
        pricingModule.processDirectWithdrawal(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = pricingModule.riskParams(assetState.creditor, assetKey);

        assertEq(actualExposure, 0);
    }
}
