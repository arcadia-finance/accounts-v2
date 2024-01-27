/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractDerivedAM_Fuzz_Test } from "./_AbstractDerivedAM.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "AbstractDerivedAM".
 */
contract GetRiskFactors_AbstractDerivedAM_Fuzz_Test is AbstractDerivedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractDerivedAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getRiskFactors(
        address creditor,
        address asset,
        uint96 assetId,
        uint16 riskFactor,
        address[2] memory underlyingAssets,
        uint256[2] memory underlyingAssetIds,
        uint16[2] memory collateralFactors,
        uint16[2] memory liquidationFactors
    ) public {
        // Given: underlyingAssets are unique.
        vm.assume(underlyingAssets[0] != underlyingAssets[1]);

        // And: id's are smaller or equal to type(uint96).max.
        underlyingAssetIds[0] = bound(underlyingAssetIds[0], 0, type(uint96).max);
        underlyingAssetIds[1] = bound(underlyingAssetIds[1], 0, type(uint96).max);

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));

        // And: Underlying assets are in primaryAM.
        registryExtension.setAssetToAssetModule(underlyingAssets[0], address(primaryAM));
        registryExtension.setAssetToAssetModule(underlyingAssets[1], address(primaryAM));
        vm.startPrank(address(registryExtension));
        primaryAM.setRiskParameters(
            creditor, underlyingAssets[0], underlyingAssetIds[0], 0, collateralFactors[0], liquidationFactors[0]
        );
        primaryAM.setRiskParameters(
            creditor, underlyingAssets[1], underlyingAssetIds[1], 0, collateralFactors[1], liquidationFactors[1]
        );
        vm.stopPrank();

        // And: Asset is in derivedAM.
        derivedAM.addAsset(
            asset,
            assetId,
            Utils.castArrayStaticToDynamic(underlyingAssets),
            Utils.castArrayStaticToDynamic(underlyingAssetIds)
        );
        vm.prank(address(registryExtension));
        derivedAM.setRiskParameters(creditor, 0, riskFactor);

        // When: "getRiskFactors" is called.
        (uint16 actualCollateralFactor, uint16 actualLiquidationFactor) =
            derivedAM.getRiskFactors(creditor, asset, assetId);

        // Then: Transaction returns correct risk factors.
        uint256 expectedCollateralFactor =
            collateralFactors[0] < collateralFactors[1] ? collateralFactors[0] : collateralFactors[1];
        expectedCollateralFactor = expectedCollateralFactor * riskFactor / AssetValuationLib.ONE_4;
        assertEq(actualCollateralFactor, expectedCollateralFactor);

        uint256 expectedLiquidationFactor =
            liquidationFactors[0] < liquidationFactors[1] ? liquidationFactors[0] : liquidationFactors[1];
        expectedLiquidationFactor = expectedLiquidationFactor * riskFactor / AssetValuationLib.ONE_4;
        assertEq(actualLiquidationFactor, expectedLiquidationFactor);
    }
}
