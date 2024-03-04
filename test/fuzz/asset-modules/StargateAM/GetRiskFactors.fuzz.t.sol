/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAM_Fuzz_Test, Constants } from "./_StargateAM.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getRiskFactors" of contract "StargateAM".
 */
contract GetRiskFactors_StargateAM_Fuzz_Test is StargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getRiskFactors(
        uint16 riskFactor,
        uint16 collateralFactor,
        uint16 liquidationFactor,
        address creditor,
        uint256 poolId
    ) public {
        // And: Risk factors are below max risk factor.
        riskFactor = uint16(bound(riskFactor, 0, AssetValuationLib.ONE_4));
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, AssetValuationLib.ONE_4));

        uint256 expectedCollateralFactor = uint256(collateralFactor) * riskFactor / AssetValuationLib.ONE_4;
        uint256 expectedLiquidationFactor = uint256(liquidationFactor) * riskFactor / AssetValuationLib.ONE_4;

        // And riskFactor is set.
        vm.prank(address(registryExtension));
        stargateAssetModule.setRiskParameters(creditor, 0, riskFactor);

        // And: pool is added
        sgFactoryMock.setPool(poolId, address(poolMock));
        poolMock.setToken(address(mockERC20.token1));
        stargateAssetModule.addAsset(poolId);

        // And riskFactor is set for token1.
        vm.prank(address(registryExtension));
        erc20AssetModule.setRiskParameters(
            creditor, address(mockERC20.token1), 0, 0, collateralFactor, liquidationFactor
        );

        (uint256 collateralFactor_, uint256 liquidationFactor_) =
            stargateAssetModule.getRiskFactors(creditor, address(poolMock), 0);
        assertEq(collateralFactor_, expectedCollateralFactor);
        assertEq(liquidationFactor_, expectedLiquidationFactor);
    }
}
