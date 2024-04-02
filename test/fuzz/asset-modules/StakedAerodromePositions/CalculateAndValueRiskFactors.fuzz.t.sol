/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedAerodromeAM_Fuzz_Test, StakedAerodromeAM, StakingAM } from "./_StakedAerodromeAM.fuzz.t.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Utils } from "../../../utils/Utils.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Fuzz tests for the "CalculateAndValueRiskFactors" function of contract "StakedAerodromeAM".
 */
contract CalculateAndValueRiskFactors_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FORK TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_CalculateAndValueRiskFactors_ValueBiggerThanZero(
        address creditor,
        uint16 riskFactor,
        uint256[1] memory assetRates,
        uint16[1] memory collateralFactors,
        uint16[1] memory liquidationFactors,
        uint256 underlyingAssetAmount
    ) public {
        uint256[] memory underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = underlyingAssetAmount;

        // Given : amounts do not overflow
        underlyingAssetsAmounts[0] = bound(underlyingAssetsAmounts[0], 0, type(uint128).max);
        assetRates[0] = bound(assetRates[0], 0, type(uint64).max);

        uint256 expectedValueInUsd = underlyingAssetsAmounts[0] * assetRates[0] / 1e18;

        // And : valueInUsd is bigger than 0
        vm.assume(expectedValueInUsd > 0);

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));

        // And riskFactor is set.
        vm.prank(address(registryExtension));
        stakedAerodromeAM.setRiskParameters(creditor, 0, riskFactor);

        uint256 expectedCollateralFactor = uint256(collateralFactors[0]) * riskFactor / AssetValuationLib.ONE_4;
        uint256 expectedLiquidationFactor = uint256(liquidationFactors[0]) * riskFactor / AssetValuationLib.ONE_4;

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](1);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: assetRates[0],
            collateralFactor: collateralFactors[0],
            liquidationFactor: liquidationFactors[0]
        });

        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) =
            stakedAerodromeAM.calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);

        assertEq(valueInUsd, expectedValueInUsd);
        assertEq(collateralFactor, expectedCollateralFactor);
        assertEq(liquidationFactor, expectedLiquidationFactor);
    }

    function testFuzz_Success_CalculateAndValueRiskFactors_ValueInUsdIsZero(
        address creditor,
        uint16 riskFactor,
        uint256[1] memory assetRates,
        uint16[1] memory collateralFactors,
        uint16[1] memory liquidationFactors,
        uint256 underlyingAssetAmount
    ) public {
        uint256[] memory underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = underlyingAssetAmount;

        // Given : expectedValueInUsd is zero
        underlyingAssetsAmounts[0] = 0;
        assetRates[0] = bound(assetRates[0], 0, type(uint64).max);

        uint256 expectedValueInUsd = underlyingAssetsAmounts[0] * assetRates[0] / 1e18;
        assertEq(expectedValueInUsd, 0);

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));

        // And riskFactor is set.
        vm.prank(address(registryExtension));
        stakedAerodromeAM.setRiskParameters(creditor, 0, riskFactor);

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](1);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: assetRates[0],
            collateralFactor: collateralFactors[0],
            liquidationFactor: liquidationFactors[0]
        });

        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) =
            stakedAerodromeAM.calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);

        assertEq(valueInUsd, 0);
        assertEq(collateralFactor, 0);
        assertEq(liquidationFactor, 0);
    }
}