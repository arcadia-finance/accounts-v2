/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Utils } from "../../../utils/Utils.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_calculateValueAndRiskFactors" of contract "WrappedMetadex03AM".
 */
contract CalculateValueAndRiskFactors_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
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
        // Given: The usd value of each underlying asset does not overflow.
        underlyingAssetsAmounts[0] = bound(
            underlyingAssetsAmounts[0], 0, assetRates[0] == 0 ? type(uint256).max : type(uint256).max / assetRates[0]
        );
        underlyingAssetsAmounts[1] = bound(
            underlyingAssetsAmounts[1], 0, assetRates[1] == 0 ? type(uint256).max : type(uint256).max / assetRates[1]
        );
        underlyingAssetsAmounts[2] = bound(
            underlyingAssetsAmounts[2], 0, assetRates[2] == 0 ? type(uint256).max : type(uint256).max / assetRates[2]
        );
        uint256 value0 = underlyingAssetsAmounts[0] * assetRates[0] / 1e18;
        uint256 value1 = underlyingAssetsAmounts[1] * assetRates[1] / 1e18;
        uint256 value2 = underlyingAssetsAmounts[2] * assetRates[2] / 1e18;
        uint256 expectedValueInUsd = value0 + value1 + value2;
        vm.assume(expectedValueInUsd > 0);

        // And: Every liquidation factor is at least its collateral factor.
        // forge-lint: disable-next-item(unsafe-typecast)
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        collateralFactors[2] = uint16(bound(collateralFactors[2], 0, AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));
        // forge-lint: disable-next-item(unsafe-typecast)
        liquidationFactors[2] = uint16(bound(liquidationFactors[2], collateralFactors[2], AssetValuationLib.ONE_4));

        // And: The protocol wide risk factor of the Creditor is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        vm.prank(address(registry));
        wrappedMetadex03AM.setRiskParameters(creditor, 0, riskFactor);

        // And: The value weighted risk factors, lowered by the protocol wide risk factor.
        // forge-lint: disable-next-item(divide-before-multiply)
        uint256 expectedCollateralFactor =
            (value0 * collateralFactors[0] + value1 * collateralFactors[1] + value2 * collateralFactors[2])
                / expectedValueInUsd * riskFactor / AssetValuationLib.ONE_4;
        // forge-lint: disable-next-item(divide-before-multiply)
        uint256 expectedLiquidationFactor =
            (value0 * liquidationFactors[0] + value1 * liquidationFactors[1] + value2 * liquidationFactors[2])
                / expectedValueInUsd * riskFactor / AssetValuationLib.ONE_4;

        // And: The rates and risk factors of the three underlying assets.
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](3);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: assetRates[0], collateralFactor: collateralFactors[0], liquidationFactor: liquidationFactors[0]
        });
        rateUnderlyingAssetsToUsd[1] = AssetValueAndRiskFactors({
            assetValue: assetRates[1], collateralFactor: collateralFactors[1], liquidationFactor: liquidationFactors[1]
        });
        rateUnderlyingAssetsToUsd[2] = AssetValueAndRiskFactors({
            assetValue: assetRates[2], collateralFactor: collateralFactors[2], liquidationFactor: liquidationFactors[2]
        });

        // When: The value and the risk factors are calculated.
        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = wrappedMetadex03AM.calculateValueAndRiskFactors(
            creditor, Utils.castArrayStaticToDynamic(underlyingAssetsAmounts), rateUnderlyingAssetsToUsd
        );

        // Then: The value is the sum of the values of the three underlying assets.
        assertEq(valueInUsd, expectedValueInUsd);

        // And: Both risk factors are value weighted.
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
        // Given: The protocol wide risk factor of the Creditor is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        vm.prank(address(registry));
        wrappedMetadex03AM.setRiskParameters(creditor, 0, riskFactor);

        // And: All three underlying assets have a zero rate.
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](3);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: 0, collateralFactor: collateralFactors[0], liquidationFactor: liquidationFactors[0]
        });
        rateUnderlyingAssetsToUsd[1] = AssetValueAndRiskFactors({
            assetValue: 0, collateralFactor: collateralFactors[1], liquidationFactor: liquidationFactors[1]
        });
        rateUnderlyingAssetsToUsd[2] = AssetValueAndRiskFactors({
            assetValue: 0, collateralFactor: collateralFactors[2], liquidationFactor: liquidationFactors[2]
        });

        // When: The value and the risk factors are calculated.
        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = wrappedMetadex03AM.calculateValueAndRiskFactors(
            creditor, Utils.castArrayStaticToDynamic(underlyingAssetsAmounts), rateUnderlyingAssetsToUsd
        );

        // Then: The value is zero.
        assertEq(valueInUsd, 0);

        // And: Both risk factors are zero.
        assertEq(collateralFactor, 0);
        assertEq(liquidationFactor, 0);
    }
}
