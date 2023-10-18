/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";

/**
 * @notice Fuzz tests for the "getValue" of contract "AbstractDerivedPricingModule".
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
    function testFuzz_Success_WithRateUnderlyingAssetsToUsd(
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
        (uint256 actualValueInUsd,,) = derivedPricingModule.getValue(
            IPricingModule.GetValueInput({
                asset: assetState.asset,
                assetId: assetState.assetId,
                assetAmount: amount,
                baseCurrency: 0
            })
        );

        // Then: Transaction returns correct "valueInUsd".
        uint256 expectedValueInUsd = rateUnderlyingAssetToUsd * assetState.exposureAssetToUnderlyingAsset / 1e18;
        assertEq(actualValueInUsd, expectedValueInUsd);
    }

    function testFuzz_Success_WithoutRateUnderlyingAssetsToUsd(
        DerivedPricingModuleAssetState memory assetState,
        UnderlyingPricingModuleState memory underlyingPMState,
        uint256 amount
    ) public {
        // Given: id's are smaller or equal to type(uint96).max.
        assetState.assetId = bound(assetState.assetId, 0, type(uint96).max);
        assetState.underlyingAssetId = bound(assetState.underlyingAssetId, 0, type(uint96).max);

        // And: State is persisted.
        setDerivedPricingModuleAssetState(assetState);
        setUnderlyingPricingModuleState(assetState.underlyingAsset, assetState.underlyingAssetId, underlyingPMState);

        // Prepare expected internal call.
        bytes memory data = abi.encodeCall(
            mainRegistryExtension.getUsdValue,
            (
                IPricingModule.GetValueInput({
                    asset: assetState.underlyingAsset,
                    assetId: assetState.underlyingAssetId,
                    assetAmount: assetState.exposureAssetToUnderlyingAsset,
                    baseCurrency: 0
                })
            )
        );

        // When: "getValue" is called.
        // Then: The Function "getUsdValue" on "MainRegistry" is called with correct parameters.
        vm.expectCall(address(mainRegistryExtension), data);
        (uint256 actualValueInUsd,,) = derivedPricingModule.getValue(
            IPricingModule.GetValueInput({
                asset: assetState.asset,
                assetId: assetState.assetId,
                assetAmount: amount,
                baseCurrency: 0
            })
        );

        // And: Transaction returns correct "valueInUsd".
        assertEq(actualValueInUsd, underlyingPMState.usdValue);
    }
}
