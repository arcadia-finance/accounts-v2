/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { Utils } from "../../../utils/Utils.sol";

/**
 * @notice Fuzz tests for the function "_calculateValueAndRiskFactors" of contract "Metadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract CalculateValueAndRiskFactors_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        Metadex03CLAM_Fuzz_Test.setUp();

        deployMetadex03CLAM(address(metadex03PositionManager));
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
        // Given: The usd value of each underlying asset does not overflow.
        underlyingAssetsAmounts[0] = bound(
            underlyingAssetsAmounts[0], 0, assetRates[0] == 0 ? type(uint256).max : type(uint256).max / assetRates[0]
        );
        underlyingAssetsAmounts[1] = bound(
            underlyingAssetsAmounts[1], 0, assetRates[1] == 0 ? type(uint256).max : type(uint256).max / assetRates[1]
        );

        // And: No risk factor exceeds 1e4, and no liquidation factor is below its collateral factor.
        collateralFactors[0] = uint16(bound(collateralFactors[0], 0, AssetValuationLib.ONE_4));
        collateralFactors[1] = uint16(bound(collateralFactors[1], 0, AssetValuationLib.ONE_4));
        liquidationFactors[0] = uint16(bound(liquidationFactors[0], collateralFactors[0], AssetValuationLib.ONE_4));
        liquidationFactors[1] = uint16(bound(liquidationFactors[1], collateralFactors[1], AssetValuationLib.ONE_4));

        // And: The protocol wide risk factor of the Creditor is set.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        vm.prank(address(registry));
        metadex03CLAM.setRiskParameters(creditor, 0, riskFactor);

        // And: Both underlying assets have a rate and risk factors.
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd = new AssetValueAndRiskFactors[](2);
        rateUnderlyingAssetsToUsd[0] = AssetValueAndRiskFactors({
            assetValue: assetRates[0], collateralFactor: collateralFactors[0], liquidationFactor: liquidationFactors[0]
        });
        rateUnderlyingAssetsToUsd[1] = AssetValueAndRiskFactors({
            assetValue: assetRates[1], collateralFactor: collateralFactors[1], liquidationFactor: liquidationFactors[1]
        });

        // When: The value and risk factors of the position are calculated.
        (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) = metadex03CLAM.calculateValueAndRiskFactors(
            creditor, Utils.castArrayStaticToDynamic(underlyingAssetsAmounts), rateUnderlyingAssetsToUsd
        );

        // Then: The value is the sum of the usd value of both underlying assets.
        assertEq(
            valueInUsd,
            underlyingAssetsAmounts[0] * assetRates[0] / 1e18 + underlyingAssetsAmounts[1] * assetRates[1] / 1e18
        );

        // And: The lowest risk factor of both underlying assets is lowered with the protocol wide risk factor.
        uint256 lowestCollateralFactor =
            collateralFactors[0] < collateralFactors[1] ? collateralFactors[0] : collateralFactors[1];
        uint256 lowestLiquidationFactor =
            liquidationFactors[0] < liquidationFactors[1] ? liquidationFactors[0] : liquidationFactors[1];
        assertEq(collateralFactor, lowestCollateralFactor * riskFactor / AssetValuationLib.ONE_4);
        assertEq(liquidationFactor, lowestLiquidationFactor * riskFactor / AssetValuationLib.ONE_4);
    }
}
