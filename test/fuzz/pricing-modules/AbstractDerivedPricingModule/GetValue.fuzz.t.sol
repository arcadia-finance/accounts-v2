/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "AbstractDerivedPricingModule".
 */
contract GetValue_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getValue_WithRateUnderlyingAssetsToUsd(
        DerivedPricingModuleAssetState memory assetState,
        uint256 rateUnderlyingAssetToUsd,
        uint256 amount
    ) public {
        // Given: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

        // And: valueInUsd does not overflow.
        if (assetState.exposureAssetToUnderlyingAsset > 0) {
            rateUnderlyingAssetToUsd =
                bound(rateUnderlyingAssetToUsd, 0, type(uint256).max / assetState.exposureAssetToUnderlyingAsset);
        }

        // And: State is persisted.
        setDerivedPricingModuleAssetState(assetState);
        derivedPricingModule.setRateUnderlyingAssetToUsd(rateUnderlyingAssetToUsd);

        // When: "getValue" is called.
        (uint256 actualValueInUsd,,) =
            derivedPricingModule.getValue(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // Then: Transaction returns correct "valueInUsd".
        uint256 expectedValueInUsd = rateUnderlyingAssetToUsd * assetState.exposureAssetToUnderlyingAsset / 1e18;
        assertEq(actualValueInUsd, expectedValueInUsd);
    }

    function testFuzz_Success_getValue_WithoutRateUnderlyingAssetsToUsd(
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 amount
    ) public {
        // Given: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

        // And: valueInUsd does not overflow.
        if (assetState.exposureAssetToUnderlyingAsset > 0) {
            underlyingPMState.usdValue =
                bound(underlyingPMState.usdValue, 0, type(uint256).max / assetState.exposureAssetToUnderlyingAsset);
        }

        // And: State is persisted.
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState, underlyingPMState);

        // Prepare expected internal call.
        address[] memory assets = new address[](1);
        uint256[] memory assetIds = new uint256[](1);
        uint256[] memory assetAmounts = new uint256[](1);
        assets[0] = assetState.underlyingAsset;
        assetIds[0] = assetState.underlyingAssetId;
        assetAmounts[0] = 1e18;
        bytes memory data =
            abi.encodeCall(mainRegistryExtension.getValuesInUsd, (assetState.creditor, assets, assetIds, assetAmounts));

        // When: "getValue" is called.
        // Then: The Function "getUsdValue" on "MainRegistry" is called with correct parameters.
        vm.expectCall(address(mainRegistryExtension), data);
        (uint256 actualValueInUsd,,) =
            derivedPricingModule.getValue(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // And: Transaction returns correct "valueInUsd".
        uint256 expectedValueInUsd = underlyingPMState.usdValue * assetState.exposureAssetToUnderlyingAsset / 1e18;
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
