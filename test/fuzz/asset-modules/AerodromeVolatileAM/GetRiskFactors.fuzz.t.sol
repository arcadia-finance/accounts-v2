/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeVolatileAM_Fuzz_Test, Constants } from "./_AerodromeVolatileAM.fuzz.t.sol";

import { FixedPointMathLib } from "../../../../src/asset-modules/abstracts/AbstractDerivedAM.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "AerodromeVolatileAM".
 */
contract GetRiskFactors_AerodromeVolatileAM_Fuzz_Test is AerodromeVolatileAM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeVolatileAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getRiskFactors(
        uint16 riskFactor,
        uint16 collateralFactor0,
        uint16 collateralFactor1,
        uint16 liquidationFactor0,
        uint16 liquidationFactor1,
        address creditor
    ) public {
        // Given: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));

        collateralFactor0 = uint16(bound(collateralFactor0, 0, AssetValuationLib.ONE_4));
        collateralFactor1 = uint16(bound(collateralFactor1, 0, AssetValuationLib.ONE_4));
        liquidationFactor0 = uint16(bound(liquidationFactor0, collateralFactor0, AssetValuationLib.ONE_4));
        liquidationFactor1 = uint16(bound(liquidationFactor1, collateralFactor1, AssetValuationLib.ONE_4));

        uint256 expectedCollateralFactor = collateralFactor0 < collateralFactor1
            ? uint256(riskFactor).mulDivDown(collateralFactor0, AssetValuationLib.ONE_4)
            : uint256(riskFactor).mulDivDown(collateralFactor1, AssetValuationLib.ONE_4);

        uint256 expectedLiquidationFactor = liquidationFactor0 < liquidationFactor1
            ? uint256(riskFactor).mulDivDown(liquidationFactor0, AssetValuationLib.ONE_4)
            : uint256(riskFactor).mulDivDown(liquidationFactor1, AssetValuationLib.ONE_4);

        // And riskFactor is set.
        vm.prank(address(registryExtension));
        aeroVolatileAM.setRiskParameters(creditor, 0, riskFactor);

        // And: pool is added
        setInitialState();
        aeroVolatileAM.addAsset(address(aeroPoolMock));

        // And riskFactors are set for token0.
        vm.startPrank(address(registryExtension));
        erc20AssetModule.setRiskParameters(
            creditor, address(mockERC20.token1), 0, 0, collateralFactor0, liquidationFactor0
        );
        // And riskFactors are set for token1.
        erc20AssetModule.setRiskParameters(
            creditor, address(mockERC20.stable1), 0, 0, collateralFactor1, liquidationFactor1
        );
        vm.stopPrank();

        // When : calling getRiskFactors()
        // Then : It should return correct values
        (uint256 collateralFactor_, uint256 liquidationFactor_) =
            aeroVolatileAM.getRiskFactors(creditor, address(aeroPoolMock), 0);
        assertEq(collateralFactor_, expectedCollateralFactor);
        assertEq(liquidationFactor_, expectedLiquidationFactor);
    }
}
