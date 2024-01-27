/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractDerivedAM_Fuzz_Test } from "./_AbstractDerivedAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getValue" of contract "AbstractDerivedAM".
 */
contract GetValue_AbstractDerivedAM_Fuzz_Test is AbstractDerivedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getValue_WithRateUnderlyingAssetsToUsd(
        DerivedAMAssetState memory assetState,
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
        setDerivedAMAssetState(assetState);
        derivedAM.setRateUnderlyingAssetToUsd(rateUnderlyingAssetToUsd);

        // When: "getValue" is called.
        (uint256 actualValueInUsd,,) =
            derivedAM.getValue(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // Then: Transaction returns correct "valueInUsd".
        uint256 expectedValueInUsd = rateUnderlyingAssetToUsd * assetState.exposureAssetToUnderlyingAsset / 1e18;
        assertEq(actualValueInUsd, expectedValueInUsd);
    }

    function testFuzz_Success_getValue_WithoutRateUnderlyingAssetsToUsd(
        DerivedAMAssetState memory assetState,
        UnderlyingAssetModuleState memory underlyingPMState,
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
        setDerivedAMAssetState(assetState);
        setUnderlyingAssetModuleState(assetState, underlyingPMState);

        // Prepare expected internal call.
        address[] memory assets = new address[](1);
        uint256[] memory assetIds = new uint256[](1);
        uint256[] memory assetAmounts = new uint256[](1);
        assets[0] = assetState.underlyingAsset;
        assetIds[0] = assetState.underlyingAssetId;
        assetAmounts[0] = 1e18;
        bytes memory data = abi.encodeCall(
            registryExtension.getValuesInUsdRecursive, (assetState.creditor, assets, assetIds, assetAmounts)
        );

        // When: "getValue" is called.
        // Then: The Function "getUsdValue" on "Registry" is called with correct parameters.
        vm.expectCall(address(registryExtension), data);
        (uint256 actualValueInUsd,,) =
            derivedAM.getValue(assetState.creditor, assetState.asset, assetState.assetId, amount);

        // And: Transaction returns correct "valueInUsd".
        uint256 expectedValueInUsd = underlyingPMState.usdValue * assetState.exposureAssetToUnderlyingAsset / 1e18;
        assertEq(actualValueInUsd, expectedValueInUsd);
    }
}
