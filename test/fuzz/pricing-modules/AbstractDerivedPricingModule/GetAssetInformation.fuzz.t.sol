/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AbstractDerivedPricingModule_Fuzz_Test } from "./_AbstractDerivedPricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "getAssetInformation" of contract "AbstractDerivedPricingModule".
 */
contract GetAssetInformation_AbstractDerivedPricingModule_Fuzz_Test is AbstractDerivedPricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedPricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAssetInformation(
        address asset,
        address underlyingAsset,
        uint128 exposureAssetLast,
        uint128 usdValueExposureAssetLast,
        uint128 exposureAssetToUnderlyingAssetsLast
    ) public {
        address[] memory underlyingAssets = new address[](1);
        underlyingAssets[0] = underlyingAsset;

        derivedPricingModule.addAsset(asset, underlyingAssets);
        derivedPricingModule.setAssetInformation(
            asset, underlyingAsset, exposureAssetLast, usdValueExposureAssetLast, exposureAssetToUnderlyingAssetsLast
        );

        (uint128 a, uint128 b, address[] memory c, uint128[] memory d) = derivedPricingModule.getAssetInformation(asset);

        assert(a == exposureAssetLast);
        assert(b == usdValueExposureAssetLast);
        assert(c[0] == underlyingAsset);
        assert(d[0] == exposureAssetToUnderlyingAssetsLast);
    }
}
