/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryAssetModule_Fuzz_Test } from "./_AbstractPrimaryAssetModule.fuzz.t.sol";

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
    function testFuzz_Revert_processDirectDeposit_NonMainRegistry(
        PrimaryAssetModuleAssetState memory assetState,
        address unprivilegedAddress_,
        uint256 amount
    ) public {
        // Given "caller" is not the Main Registry.
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is deposited.
        // Then: The transaction reverts with "AAM: ONLY_MAIN_REGISTRY".
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("AAM: ONLY_MAIN_REGISTRY");
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

        // And: "exposureAsset" is bigger than"exposureAssetMax" (test-case).
        vm.assume(expectedExposure > 0);
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, 0, expectedExposure - 1));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is deposited.
        // Then: The transaction reverts with "APAM_PDD: Exposure not in limits".
        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("APAM_PDD: Exposure not in limits");
        assetModule.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(PrimaryAssetModuleAssetState memory assetState, uint256 amount)
        public
    {
        // Given: "exposureAsset" is smaller or equal as "exposureAssetMax" (test-case).
        amount = bound(amount, 0, type(uint128).max - assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast + amount;
        assetState.exposureAssetMax = uint128(bound(assetState.exposureAssetMax, expectedExposure, type(uint128).max));

        // And: State is persisted.
        setPrimaryAssetModuleAssetState(assetState);

        // When: "amount" is deposited.
        vm.prank(address(mainRegistryExtension));
        assetModule.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);

        assertEq(actualExposure, expectedExposure);
    }
}
