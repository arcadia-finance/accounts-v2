/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "_calculateValueAndRiskFactors" of contract "StakedMetadex03CLAM".
 */
contract CalculateValueAndRiskFactors_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function toRates(
        uint256[3] memory assetRates,
        uint16[3] memory collateralFactors,
        uint16[3] memory liquidationFactors
    ) internal pure returns (AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) {
        rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](3);
        for (uint256 i; i < 3; ++i) {
            rateUnderlyingAssetsToUsd[i] = AssetValueAndRiskFactors({
                assetValue: assetRates[i],
                collateralFactor: collateralFactors[i],
                liquidationFactor: liquidationFactors[i]
            });
        }
    }

    function weightedFactor(uint256 valuePrincipal, uint256 valueReward, uint16[3] memory factors, uint16 riskFactor)
        internal
        pure
        returns (uint256 factor)
    {
        factor = factors[0] < factors[1] ? factors[0] : factors[1];
        // forge-lint: disable-next-item(divide-before-multiply)
        factor = (valuePrincipal * factor + valueReward * factors[2]) / (valuePrincipal + valueReward);
        // forge-lint: disable-next-item(divide-before-multiply)
        factor = factor * riskFactor / AssetValuationLib.ONE_4;
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_calculateValueAndRiskFactors_ValueOverflow(
        uint256 assetRate,
        uint256 underlyingAssetsAmount,
        address creditor
    ) public {
        // Given: The amount and the rate of the first underlying asset overflow their product.
        assetRate = bound(assetRate, 2, type(uint256).max);
        underlyingAssetsAmount = bound(underlyingAssetsAmount, type(uint256).max / assetRate + 1, type(uint256).max);
        uint256[] memory underlyingAssetsAmounts = new uint256[](3);
        underlyingAssetsAmounts[0] = underlyingAssetsAmount;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](3);
        rateUnderlyingAssetsToUsd[0] =
            AssetValueAndRiskFactors({ assetValue: assetRate, collateralFactor: 0, liquidationFactor: 0 });

        // When: Calling _calculateValueAndRiskFactors().
        // Then: It reverts, mulDivDown() rejects the overflowing product.
        vm.expectRevert(bytes(""));
        stakedMetadex03CLAM.calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    function testFuzz_Success_calculateValueAndRiskFactors_ZeroValueInUsd(
        uint16[3] memory collateralFactors,
        uint16[3] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[3] memory underlyingAssetsAmounts
    ) public {
        // Given: The USD rate of every underlying asset is zero.
        uint256[3] memory assetRates;

        // And: Collateral factors are at most ONE_4, and liquidation factors are not below them.
        for (uint256 i; i < 3; ++i) {
            // forge-lint: disable-next-item(unsafe-typecast)
            collateralFactors[i] = uint16(bound(collateralFactors[i], 0, AssetValuationLib.ONE_4));
            // forge-lint: disable-next-item(unsafe-typecast)
            liquidationFactors[i] = uint16(bound(liquidationFactors[i], collateralFactors[i], AssetValuationLib.ONE_4));
        }

        // And: The protocol wide risk factor is at most ONE_4, and is set for the creditor.
        // forge-lint: disable-next-item(unsafe-typecast)
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        vm.prank(address(registry));
        stakedMetadex03CLAM.setRiskParameters(creditor, 0, riskFactor);

        // When: Calling _calculateValueAndRiskFactors().
        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = stakedMetadex03CLAM.calculateValueAndRiskFactors(
            creditor,
            Utils.castArrayStaticToDynamic(underlyingAssetsAmounts),
            toRates(assetRates, collateralFactors, liquidationFactors)
        );

        // Then: Nothing is valued and both risk factors are zero.
        assertEq(valueInUsd, 0);
        assertEq(collateralFactor, 0);
        assertEq(liquidationFactor, 0);
    }

    function testFuzz_Success_calculateValueAndRiskFactors_NonZeroValueInUsd(
        uint256[3] memory assetRates,
        uint16[3] memory collateralFactors,
        uint16[3] memory liquidationFactors,
        uint16 riskFactor,
        address creditor,
        uint256[3] memory underlyingAssetsAmounts,
        uint256 valuedIndex
    ) public {
        // Given: The USD value of one of the underlying assets is not zero.
        valuedIndex = bound(valuedIndex, 0, 2);
        vm.assume(assetRates[valuedIndex] != 0);
        underlyingAssetsAmounts[valuedIndex] = bound(
            underlyingAssetsAmounts[valuedIndex],
            1e18 / assetRates[valuedIndex] + 1,
            type(uint256).max / assetRates[valuedIndex]
        );

        // And: The amount and the rate of every other underlying asset do not overflow the product.
        for (uint256 i; i < 3; ++i) {
            if (i == valuedIndex || assetRates[i] == 0) continue;
            underlyingAssetsAmounts[i] = bound(underlyingAssetsAmounts[i], 0, type(uint256).max / assetRates[i]);
        }

        // And: Collateral factors are at most ONE_4, and liquidation factors are not below them.
        for (uint256 i; i < 3; ++i) {
            // forge-lint: disable-next-item(unsafe-typecast)
            collateralFactors[i] = uint16(bound(collateralFactors[i], 0, AssetValuationLib.ONE_4));
            // forge-lint: disable-next-item(unsafe-typecast)
            liquidationFactors[i] = uint16(bound(liquidationFactors[i], collateralFactors[i], AssetValuationLib.ONE_4));
        }

        // And: The protocol wide risk factor is at most ONE_4, and is set for the creditor.
        // forge-lint: disable-next-item(unsafe-typecast)
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        vm.prank(address(registry));
        stakedMetadex03CLAM.setRiskParameters(creditor, 0, riskFactor);

        // When: Calling _calculateValueAndRiskFactors().
        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = stakedMetadex03CLAM.calculateValueAndRiskFactors(
            creditor,
            Utils.castArrayStaticToDynamic(underlyingAssetsAmounts),
            toRates(assetRates, collateralFactors, liquidationFactors)
        );

        // Then: The value is the sum of the value of the principal and of the reward.
        uint256 valuePrincipal = FullMath.mulDiv(underlyingAssetsAmounts[0], assetRates[0], 1e18)
            + FullMath.mulDiv(underlyingAssetsAmounts[1], assetRates[1], 1e18);
        uint256 valueReward = FullMath.mulDiv(underlyingAssetsAmounts[2], assetRates[2], 1e18);
        assertEq(valueInUsd, valuePrincipal + valueReward);

        // And: Both risk factors are the value weighted average, lowered with the protocol wide risk factor.
        assertEq(collateralFactor, weightedFactor(valuePrincipal, valueReward, collateralFactors, riskFactor));
        assertEq(liquidationFactor, weightedFactor(valuePrincipal, valueReward, liquidationFactors, riskFactor));
    }
}
