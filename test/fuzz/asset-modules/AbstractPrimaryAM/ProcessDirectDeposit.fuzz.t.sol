/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractPrimaryAM_Fuzz_Test, AssetModule } from "./_AbstractPrimaryAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "AbstractPrimaryAM".
 */
contract ProcessDirectDeposit_AbstractPrimaryAM_Fuzz_Test is AbstractPrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonRegistry(
        PrimaryAMAssetState memory assetState,
        address unprivilegedAddress_,
        uint256 amount
    ) public {
        // Given "caller" is not the Registry.
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        // And: State is persisted.
        setPrimaryAMAssetState(assetState);

        // When: "amount" is deposited.
        // Then: The transaction reverts with AssetModule.OnlyRegistry.selector.
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        assetModule.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_OverExposure(PrimaryAMAssetState memory assetState, uint256 amount)
        public
    {
        // Given: "exposureAssetLast" does not overflow.
        amount = bound(amount, 0, type(uint256).max - assetState.exposureAssetLast);
        uint256 expectedExposure = assetState.exposureAssetLast + amount;

        // And: "exposureAsset" is bigger or equal as "exposureAssetMax" (test-case).
        assetState.exposureAssetMax = uint112(bound(assetState.exposureAssetMax, 0, expectedExposure));

        // And: State is persisted.
        setPrimaryAMAssetState(assetState);

        // When: "amount" is deposited.
        // Then: The transaction reverts with AssetModule.ExposureNotInLimits.selector.
        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        assetModule.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectDeposit(PrimaryAMAssetState memory assetState, uint256 amount) public {
        // Given: "exposureAsset" is strictly smaller than "exposureAssetMax" (test-case).
        assetState.exposureAssetLast = uint112(bound(assetState.exposureAssetLast, 0, type(uint112).max - 1));
        amount = bound(amount, 0, type(uint112).max - assetState.exposureAssetLast - 1);
        uint256 expectedExposure = assetState.exposureAssetLast + amount;
        assetState.exposureAssetMax =
            uint112(bound(assetState.exposureAssetMax, expectedExposure + 1, type(uint112).max));

        // And: State is persisted.
        setPrimaryAMAssetState(assetState);

        // When: "amount" is deposited.
        vm.prank(address(registryExtension));
        (uint256 recursiveCalls, uint256 assetType) =
            assetModule.processDirectDeposit(assetState.creditor, assetState.asset, assetState.assetId, amount);

        assertEq(recursiveCalls, 1);
        assertEq(assetType, 0);

        // Then: assetExposure is updated.
        bytes32 assetKey = bytes32(abi.encodePacked(assetState.assetId, assetState.asset));
        (uint128 actualExposure,,,) = assetModule.riskParams(assetState.creditor, assetKey);

        assertEq(actualExposure, expectedExposure);
    }
}
