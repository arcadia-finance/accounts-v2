/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AbstractPrimaryAssetModule_Fuzz_Test, AssetModule } from "./_AbstractPrimaryAssetModule.fuzz.t.sol";

import { RiskModule } from "../../../../src/RiskModule.sol";
import { PrimaryAssetModule } from "../../../../src/asset-modules/AbstractPrimaryAssetModule.sol";

/**
 * @notice Fuzz tests for the function "setRiskParameters" of contract "AbstractPrimaryAssetModule".
 */
contract SetRiskParameters_AbstractPrimaryAssetModule_Fuzz_Test is AbstractPrimaryAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParameters_NonRegistry(
        address unprivilegedAddress_,
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.Only_Registry.selector);
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_CollateralFactorNotInLimits(
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, RiskModule.ONE_4 + 1, type(uint16).max));

        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.Coll_Factor_Not_In_Limits.selector);
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_LiquidationFactorNotInLimits(
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, RiskModule.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, RiskModule.ONE_4 + 1, type(uint16).max));

        vm.startPrank(address(registryExtension));
        vm.expectRevert(AssetModule.Liq_Factor_Not_In_Limits.selector);
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_CollFactorExceedsLiqFactor(
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 1, RiskModule.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, 0, collateralFactor - 1));

        vm.startPrank(address(registryExtension));
        vm.expectRevert(PrimaryAssetModule.CollFactorExceedsLiqFactor.selector);
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParameters(
        address creditor,
        address asset,
        uint96 assetId,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, RiskModule.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, RiskModule.ONE_4));

        vm.prank(address(registryExtension));
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);

        bytes32 assetKey = bytes32(abi.encodePacked(assetId, asset));
        (, uint128 actualMaxExposure, uint16 actualCollateralFactor, uint16 actualLiquidationFactor) =
            assetModule.riskParams(creditor, assetKey);
        assertEq(actualMaxExposure, maxExposure);
        assertEq(actualCollateralFactor, collateralFactor);
        assertEq(actualLiquidationFactor, liquidationFactor);
    }
}
