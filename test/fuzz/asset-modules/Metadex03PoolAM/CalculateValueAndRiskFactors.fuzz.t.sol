/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { Metadex03PoolAM_Fuzz_Test } from "./_Metadex03PoolAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "_calculateValueAndRiskFactors" of contract "Metadex03PoolAM".
 */
contract CalculateValueAndRiskFactors_Metadex03PoolAM_Fuzz_Test is Metadex03PoolAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03PoolAM_Fuzz_Test.setUp();
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
        // Given: The usd value of underlying asset 0 fits in uint256.
        underlyingAssetsAmounts[0] = bound(
            underlyingAssetsAmounts[0], 0, assetRates[0] == 0 ? type(uint256).max : type(uint256).max / assetRates[0]
        );
        uint256 value0 = underlyingAssetsAmounts[0] * assetRates[0] / 1e18;

        // And: The usd value of underlying asset 1 fits in uint256, as does the sum of both.
        uint256 maxAmount1 = assetRates[1] == 0 ? type(uint256).max : type(uint256).max / assetRates[1];
        if (maxAmount1 * assetRates[1] / 1e18 > type(uint256).max - value0) {
            maxAmount1 = FullMath.mulDiv(type(uint256).max - value0, 1e18, assetRates[1]);
        }
        underlyingAssetsAmounts[1] = bound(underlyingAssetsAmounts[1], 0, maxAmount1);

        // And: The protocol wide risk factor is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        vm.prank(address(registry));
        metadex03PoolAM.setRiskParameters(creditor, 0, riskFactor);

        // And: Both underlying assets carry valid risk factors.
        // forge-lint: disable-next-item(unsafe-typecast)
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](2);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: assetRates[0], collateralFactor: collateralFactors[0], liquidationFactor: liquidationFactors[0]
        });
        rateUnderlyingAssetsToUsd[1] = AssetValueAndRiskFactors({
            assetValue: assetRates[1], collateralFactor: collateralFactors[1], liquidationFactor: liquidationFactors[1]
        });

        // When: The value and risk factors are calculated.
        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = metadex03PoolAM.calculateValueAndRiskFactors(
            creditor, Utils.castArrayStaticToDynamic(underlyingAssetsAmounts), rateUnderlyingAssetsToUsd
        );

        // Then: The value is the sum of the usd value of both underlying assets.
        assertEq(valueInUsd, value0 + underlyingAssetsAmounts[1] * assetRates[1] / 1e18);

        // And: Both risk factors are the lowest of the underlying assets, lowered with the protocol wide risk factor.
        uint256 expectedCollateralFactor =
            collateralFactors[0] < collateralFactors[1] ? collateralFactors[0] : collateralFactors[1];
        uint256 expectedLiquidationFactor =
            liquidationFactors[0] < liquidationFactors[1] ? liquidationFactors[0] : liquidationFactors[1];
        assertEq(collateralFactor, expectedCollateralFactor * riskFactor / AssetValuationLib.ONE_4);
        assertEq(liquidationFactor, expectedLiquidationFactor * riskFactor / AssetValuationLib.ONE_4);
    }
}
