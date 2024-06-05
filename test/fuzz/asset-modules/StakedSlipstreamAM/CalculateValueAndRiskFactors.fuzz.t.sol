/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "_calculateValueAndRiskFactors" of contract "StakedSlipstreamAM".
 */
contract CalculateValueAndRiskFactors_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_calculateValueAndRiskFactors_NonZeroValueInUsd(
        uint256[3] memory assetRates,
        uint16[3] memory collateralFactors,
        uint16[3] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[3] memory underlyingAssetsAmounts
    ) public {
        // Given amounts do not overflow.
        underlyingAssetsAmounts[0] = bound(underlyingAssetsAmounts[0], 0, type(uint64).max);
        underlyingAssetsAmounts[1] = bound(underlyingAssetsAmounts[1], 0, type(uint64).max);
        underlyingAssetsAmounts[2] = bound(underlyingAssetsAmounts[2], 0, type(uint64).max);
        assetRates[0] = bound(assetRates[0], 0, type(uint64).max);
        assetRates[1] = bound(assetRates[1], 0, type(uint64).max);
        assetRates[2] = bound(assetRates[2], 0, type(uint64).max);

        uint256 valuePrincipal =
            underlyingAssetsAmounts[0] * assetRates[0] / 1e18 + underlyingAssetsAmounts[1] * assetRates[1] / 1e18;
        uint256 valueReward = underlyingAssetsAmounts[2] * assetRates[2] / 1e18;
        uint256 expectedValueInUsd = valuePrincipal + valueReward;
        vm.assume(expectedValueInUsd > 0);

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        collateralFactors[2] = uint16(bound(collateralFactors[2], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));
        liquidationFactors[2] = uint16(bound(liquidationFactors[2], collateralFactors[1], AssetValuationLib.ONE_4));

        // And riskFactor is set.
        vm.prank(address(registryExtension));
        stakedSlipstreamAM.setRiskParameters(creditor, 0, riskFactor);

        uint256 expectedCollateralFactor =
            collateralFactors[0] < collateralFactors[1] ? collateralFactors[0] : collateralFactors[1];
        uint256 expectedLiquidationFactor =
            liquidationFactors[0] < liquidationFactors[1] ? liquidationFactors[0] : liquidationFactors[1];
        expectedCollateralFactor =
            (valuePrincipal * expectedCollateralFactor + valueReward * collateralFactors[2]) / expectedValueInUsd;
        expectedLiquidationFactor =
            (valuePrincipal * expectedLiquidationFactor + valueReward * liquidationFactors[2]) / expectedValueInUsd;
        expectedCollateralFactor = expectedCollateralFactor * riskFactor / AssetValuationLib.ONE_4;
        expectedLiquidationFactor = expectedLiquidationFactor * riskFactor / AssetValuationLib.ONE_4;

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](3);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: assetRates[0],
            collateralFactor: collateralFactors[0],
            liquidationFactor: liquidationFactors[0]
        });
        rateUnderlyingAssetsToUsd[1] = AssetValueAndRiskFactors({
            assetValue: assetRates[1],
            collateralFactor: collateralFactors[1],
            liquidationFactor: liquidationFactors[1]
        });
        rateUnderlyingAssetsToUsd[2] = AssetValueAndRiskFactors({
            assetValue: assetRates[2],
            collateralFactor: collateralFactors[2],
            liquidationFactor: liquidationFactors[2]
        });

        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = stakedSlipstreamAM
            .calculateValueAndRiskFactors(
            creditor, Utils.castArrayStaticToDynamic(underlyingAssetsAmounts), rateUnderlyingAssetsToUsd
        );
        assertEq(valueInUsd, expectedValueInUsd);
        assertEq(collateralFactor, expectedCollateralFactor);
        assertEq(liquidationFactor, expectedLiquidationFactor);
    }

    function testFuzz_Success_calculateValueAndRiskFactors_ZeroValueInUsd(
        uint16[3] memory collateralFactors,
        uint16[3] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[3] memory underlyingAssetsAmounts
    ) public {
        // And riskFactor is set.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        vm.prank(address(registryExtension));
        stakedSlipstreamAM.setRiskParameters(creditor, 0, riskFactor);

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](3);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: 0,
            collateralFactor: collateralFactors[0],
            liquidationFactor: liquidationFactors[0]
        });
        rateUnderlyingAssetsToUsd[1] = AssetValueAndRiskFactors({
            assetValue: 0,
            collateralFactor: collateralFactors[1],
            liquidationFactor: liquidationFactors[1]
        });
        rateUnderlyingAssetsToUsd[2] = AssetValueAndRiskFactors({
            assetValue: 0,
            collateralFactor: collateralFactors[2],
            liquidationFactor: liquidationFactors[2]
        });

        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = stakedSlipstreamAM
            .calculateValueAndRiskFactors(
            creditor, Utils.castArrayStaticToDynamic(underlyingAssetsAmounts), rateUnderlyingAssetsToUsd
        );
        assertEq(valueInUsd, 0);
        assertEq(collateralFactor, 0);
        assertEq(liquidationFactor, 0);
    }
}
