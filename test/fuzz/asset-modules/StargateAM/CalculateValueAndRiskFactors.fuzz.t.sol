/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAM_Fuzz_Test, Constants } from "./_StargateAM.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "_calculateValueAndRiskFactors" of contract "StargateAM".
 */
contract CalculateValueAndRiskFactors_StargateAM_Fuzz_Test is StargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_calculateValueAndRiskFactors(
        uint16 riskFactor,
        uint256 assetRate,
        uint16 collateralFactor,
        uint16 liquidationFactor,
        address creditor,
        uint256 underlyingAssetsAmount
    ) public {
        // Given value do not overflow.
        if (underlyingAssetsAmount > 0) {
            assetRate = bound(assetRate, 0, type(uint256).max / underlyingAssetsAmount);
        }
        uint256 expectedValueInUsd = underlyingAssetsAmount * assetRate / 1e18;

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, 0, AssetValuationLib.ONE_4));

        uint256 expectedCollateralFactor = uint256(collateralFactor) * riskFactor / AssetValuationLib.ONE_4;
        uint256 expectedLiquidationFactor = uint256(liquidationFactor) * riskFactor / AssetValuationLib.ONE_4;

        // And riskFactor is set.
        vm.prank(address(registryExtension));
        stargateAssetModule.setRiskParameters(creditor, 0, riskFactor);

        uint256[] memory underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = underlyingAssetsAmount;

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](1);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: assetRate,
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        (uint256 valueInUsd, uint256 collateralFactor_, uint256 liquidationFactor_) = stargateAssetModule
            .calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
        assertEq(valueInUsd, expectedValueInUsd);
        assertEq(collateralFactor_, expectedCollateralFactor);
        assertEq(liquidationFactor_, expectedLiquidationFactor);
    }
}
