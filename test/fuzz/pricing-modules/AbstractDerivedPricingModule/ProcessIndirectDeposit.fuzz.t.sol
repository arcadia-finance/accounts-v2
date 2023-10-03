/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processIndirectDeposit" of contract "AbstractDerivedPricingModule".
 * @notice Tests performed here will validate the recursion flow of derived pricing modules.
 * Testing for conversion rates and getValue() will be done in pricing modules testing separately.
 */
contract ProcessIndirectDeposit_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonMainRegistry(
        address unprivilegedAddress_,
        address asset,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        derivedPricingModule.processIndirectDeposit(
            asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit_ZeroExposureAsset(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 id,
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
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, underlyingPMState);

        // When: "MainRegistry" calls "processDirectDeposit".
        vm.prank(address(mainRegistryExtension));
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            assetState.asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset_
        );

        // Then: PRIMARY_FLAG is false.
        assertFalse(PRIMARY_FLAG);

        // And:
        assertEq(usdValueExposureUpperAssetToAsset, 0);
    }

    function testFuzz_Success_processIndirectDeposit_ZeroUsdValueExposureAsset(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "usdValueExposureAsset" is 0 (test-case).
        underlyingPMState.usdValueExposureToUnderlyingAsset = 0;

        // And: Deposit does not revert.
        (protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset) =
        givenNonRevertingDeposit(
            protocolState, assetState, underlyingPMState, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // And: State is persisted.
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, underlyingPMState);

        // When: "MainRegistry" calls "processIndirectDeposit".
        vm.prank(address(mainRegistryExtension));
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            assetState.asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // Then: PRIMARY_FLAG is false.
        assertFalse(PRIMARY_FLAG);

        // Correct "usdValueExposureUpperAssetToAsset" is returned.
        assertEq(usdValueExposureUpperAssetToAsset, 0);
    }

    function testFuzz_Success_processIndirectDeposit_NonZeroValues(
        DerivedPricingModuleProtocolState memory protocolState,
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 id,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset
    ) public {
        // Given: "usdValueExposureToUnderlyingAsset" is not zero (test-case).
        underlyingPMState.usdValueExposureToUnderlyingAsset =
            bound(underlyingPMState.usdValueExposureToUnderlyingAsset, 1, type(uint128).max);

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
        setDerivedPricingModuleProtocolState(protocolState);
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, underlyingPMState);

        // When: "MainRegistry" calls "processIndirectDeposit".
        vm.prank(address(mainRegistryExtension));
        (bool PRIMARY_FLAG, uint256 usdValueExposureUpperAssetToAsset) = derivedPricingModule.processIndirectDeposit(
            assetState.asset, id, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        // Then: PRIMARY_FLAG is false.
        assertFalse(PRIMARY_FLAG);

        // And: Correct "usdValueExposureUpperAssetToAsset" is returned.
        uint256 usdValueExposureUpperAssetToAssetExpected =
            underlyingPMState.usdValueExposureToUnderlyingAsset * exposureUpperAssetToAsset / exposureAsset;
        assertEq(usdValueExposureUpperAssetToAsset, usdValueExposureUpperAssetToAssetExpected);
    }
}
