/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { RiskModule } from "../../../../src/RiskModule.sol";

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

        // Prepare input.
        bytes32[] memory underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] =
            bytes32(abi.encodePacked(uint96(assetState.underlyingAssetId), assetState.underlyingAsset));

        // Prepare expected internal call.
        address[] memory assets = new address[](1);
        uint256[] memory assetIds = new uint256[](1);
        uint256[] memory assetAmounts = new uint256[](1);
        assets[0] = assetState.underlyingAsset;
        assetIds[0] = assetState.underlyingAssetId;
        assetAmounts[0] = 1e18;
        bytes memory data =
            abi.encodeCall(mainRegistryExtension.getValuesInUsd, (assetState.creditor, assets, assetIds, assetAmounts));

        // When: "_getRateUnderlyingAssetsToUsd" is called.
        // Then: The Function "getUsdValue" on "MainRegistry" is called with correct parameters.
        vm.expectCall(address(mainRegistryExtension), data);
        RiskModule.AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd =
            derivedPricingModule.getRateUnderlyingAssetsToUsd(assetState.creditor, underlyingAssetKeys);

        // And: Transaction returns correct "rateUnderlyingAssetsToUsd".
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, underlyingPMState.usdValue);
    }
}
