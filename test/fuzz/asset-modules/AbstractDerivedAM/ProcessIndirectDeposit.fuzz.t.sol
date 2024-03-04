/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractDerivedAM_Fuzz_Test, AssetModule } from "./_AbstractDerivedAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "AbstractDerivedAM".
 */
contract ProcessIndirectDeposit_AbstractDerivedAM_Fuzz_Test is AbstractDerivedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonRegistry(
        address unprivilegedAddress_,
        address creditor,
        address asset,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        derivedAM.processIndirectDeposit(creditor, asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit_ZeroExposureAsset(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: exposureAsset is zero Underflow on exposureAsset (test-case).
        deltaExposureUpperAssetToAsset =
            bound(deltaExposureUpperAssetToAsset, assetState.exposureAssetLast, uint256(type(int256).max));
        int256 deltaExposureUpperAssetToAsset_ = -int256(deltaExposureUpperAssetToAsset);

        // And: Deposit does not revert.
        (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset_) =
        givenNonRevertingDeposit(
            protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset_
        );

        // And: State is persisted.
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "Registry" calls "processDirectDeposit".
        vm.prank(address(registryExtension));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = derivedAM.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset_
        );

        // Then: recursiveCalls is correct.
        assertEq(recursiveCalls, 2);

        // And: Correct "usdExposureUpperAssetToAsset" is returned.
        assertEq(usdExposureUpperAssetToAsset, 0);
    }

    function testFuzz_Success_processIndirectDeposit_ZeroUsdValueExposureAsset(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "usdExposureAsset" is 0 (test-case).
        underlyingPMState.usdValue = 0;

        // And: Deposit does not revert.
        (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset) =
        givenNonRevertingDeposit(
            protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // And: State is persisted.
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "Registry" calls "processIndirectDeposit".
        vm.prank(address(registryExtension));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = derivedAM.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );

        // Then: recursiveCalls is correct.
        assertEq(recursiveCalls, 2);

        // Correct "usdExposureUpperAssetToAsset" is returned.
        assertEq(usdExposureUpperAssetToAsset, 0);
    }

    function testFuzz_Success_processIndirectDeposit_NonZeroValues(
        DerivedAMProtocolState memory protocolState,
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "usdExposureToUnderlyingAsset" is not zero (test-case).
        underlyingPMState.usdValue = bound(underlyingPMState.usdValue, 1, type(uint112).max);

        // And: Deposit does not revert.
        (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset) =
        givenNonRevertingDeposit(
            protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // And: exposureAsset is not zero (test-case).
        uint256 exposureAsset;
        if (deltaExposureUpperAssetToAsset > 0) {
            exposureAsset = assetState.exposureAssetLast + uint256(deltaExposureUpperAssetToAsset);
            vm.assume(exposureAsset != 0);
        } else {
            vm.assume(uint256(-deltaExposureUpperAssetToAsset) < assetState.exposureAssetLast);
            exposureAsset = uint256(assetState.exposureAssetLast) - uint256(-deltaExposureUpperAssetToAsset);
        }

        // And: State is persisted.
        setDerivedAMProtocolState(protocolState, assetState.creditor);
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // When: "Registry" calls "processIndirectDeposit".
        vm.prank(address(registryExtension));
        (uint256 recursiveCalls, uint256 usdExposureUpperAssetToAsset) = derivedAM.processIndirectDeposit(
            assetState.creditor,
            assetState.asset,
            assetState.assetId,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );

        // Then: recursiveCalls is correct.
        assertEq(recursiveCalls, 2);

        // And: Correct "usdExposureUpperAssetToAsset" is returned.
        uint256 usdExposureUpperAssetToAssetExpected =
            underlyingPMState.usdValue * exposureUpperAssetToAsset / exposureAsset;
        assertEq(usdExposureUpperAssetToAsset, usdExposureUpperAssetToAssetExpected);
    }
}
