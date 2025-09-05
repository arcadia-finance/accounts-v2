/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "_calculateValueAndRiskFactors" of contract "DefaultUniswapV4AM".
 */
contract CalculateValueAndRiskFactors_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_calculateValueAndRiskFactors(
        uint256[2] memory assetRates,
        uint16[2] memory collateralFactors,
        uint16[2] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[2] memory underlyingAssetsAmounts
    ) public {
        // Given amounts do not overflow.
        underlyingAssetsAmounts[0] = bound(underlyingAssetsAmounts[0], 0, type(uint64).max);
        underlyingAssetsAmounts[1] = bound(underlyingAssetsAmounts[1], 0, type(uint64).max);
        assetRates[0] = bound(assetRates[0], 0, type(uint64).max);
        assetRates[1] = bound(assetRates[1], 0, type(uint64).max);

        uint256 value0 = underlyingAssetsAmounts[0] * assetRates[0] / 1e18;
        uint256 value1 = underlyingAssetsAmounts[1] * assetRates[1] / 1e18;
        uint256 expectedValueInUsd = value0 + value1;

        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));

        // And riskFactor is set.
        vm.prank(address(v4HooksRegistry));
        uniswapV4AM.setRiskParameters(creditor, 0, riskFactor);

        uint256 expectedCollateralFactor =
            collateralFactors[0] < collateralFactors[1] ? collateralFactors[0] : collateralFactors[1];
        uint256 expectedLiquidationFactor =
            liquidationFactors[0] < liquidationFactors[1] ? liquidationFactors[0] : liquidationFactors[1];
        expectedCollateralFactor = expectedCollateralFactor * riskFactor / AssetValuationLib.ONE_4;
        expectedLiquidationFactor = expectedLiquidationFactor * riskFactor / AssetValuationLib.ONE_4;

        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](2);
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

        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = uniswapV4AM
            .calculateValueAndRiskFactors(
            creditor, Utils.castArrayStaticToDynamic(underlyingAssetsAmounts), rateUnderlyingAssetsToUsd
        );
        assertEq(valueInUsd, expectedValueInUsd);
        assertEq(collateralFactor, expectedCollateralFactor);
        assertEq(liquidationFactor, expectedLiquidationFactor);
    }
}
