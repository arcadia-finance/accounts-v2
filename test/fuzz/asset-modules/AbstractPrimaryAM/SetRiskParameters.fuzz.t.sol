/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractPrimaryAM_Fuzz_Test, AssetModule } from "./_AbstractPrimaryAM.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { PrimaryAM } from "../../../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";

/**
 * @notice Fuzz tests for the function "setRiskParameters" of contract "AbstractPrimaryAM".
 */
contract SetRiskParameters_AbstractPrimaryAM_Fuzz_Test is AbstractPrimaryAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AbstractPrimaryAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParameters_NonRegistry(
        address unprivilegedAddress_,
        address creditor,
        address asset,
        uint96 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        vm.assume(unprivilegedAddress_ != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_CollateralFactorNotInLimits(
        address creditor,
        address asset,
        uint96 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, AssetValuationLib.ONE_4 + 1, type(uint16).max));

        vm.startPrank(address(registryExtension));
        vm.expectRevert(PrimaryAM.CollFactorNotInLimits.selector);
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_LiquidationFactorNotInLimits(
        address creditor,
        address asset,
        uint96 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, AssetValuationLib.ONE_4 + 1, type(uint16).max));

        vm.startPrank(address(registryExtension));
        vm.expectRevert(PrimaryAM.LiqFactorNotInLimits.selector);
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParameters_CollFactorExceedsLiqFactor(
        address creditor,
        address asset,
        uint96 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 1, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, 0, collateralFactor - 1));

        vm.startPrank(address(registryExtension));
        vm.expectRevert(PrimaryAM.CollFactorExceedsLiqFactor.selector);
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);
        vm.stopPrank();
    }

    function testFuzz_Success_setRiskParameters(
        address creditor,
        address asset,
        uint96 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, AssetValuationLib.ONE_4));

        vm.prank(address(registryExtension));
        assetModule.setRiskParameters(creditor, asset, assetId, maxExposure, collateralFactor, liquidationFactor);

        bytes32 assetKey = bytes32(abi.encodePacked(assetId, asset));
        (, uint112 actualMaxExposure, uint16 actualCollateralFactor, uint16 actualLiquidationFactor) =
            assetModule.riskParams(creditor, assetKey);
        assertEq(actualMaxExposure, maxExposure);
        assertEq(actualCollateralFactor, collateralFactor);
        assertEq(actualLiquidationFactor, liquidationFactor);
    }
}
