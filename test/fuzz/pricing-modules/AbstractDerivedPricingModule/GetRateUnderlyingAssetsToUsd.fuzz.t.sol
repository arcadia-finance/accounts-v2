/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getRateUnderlyingAssetsToUsd" of contract "AbstractDerivedPricingModule".
 */
contract GetRateUnderlyingAssetsToUsd_AbstractDerivedPricingModule_Fuzz_Test is
    AbstractDerivedPricingModule_Fuzz_Test
{
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getRateUnderlyingAssetsToUsd(
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState
    ) public {
        // Given: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

        // And: State is persisted.
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState, underlyingPMState);

        // Prepare input and expected internal call.
        bytes32[] memory underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] =
            bytes32(abi.encodePacked(uint96(assetState.underlyingAssetId), assetState.underlyingAsset));

        bytes memory data = abi.encodeCall(
            mainRegistryExtension.getUsdValue,
            (address(0), assetState.underlyingAsset, assetState.underlyingAssetId, 1e18)
        );

        // When: "_getRateUnderlyingAssetsToUsd" is called.
        // Then: The Function "getUsdValue" on "MainRegistry" is called with correct parameters.
        vm.expectCall(address(mainRegistryExtension), data);
        uint256[] memory rateUnderlyingAssetsToUsd =
            derivedPricingModule.getRateUnderlyingAssetsToUsd(underlyingAssetKeys);

        // And: Transaction returns correct "rateUnderlyingAssetsToUsd".
        assertEq(rateUnderlyingAssetsToUsd[0], underlyingPMState.usdValue);
    }
}
