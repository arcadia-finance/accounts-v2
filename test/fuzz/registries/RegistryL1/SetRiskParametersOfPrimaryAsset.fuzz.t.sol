/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { RegistryL1_Fuzz_Test, RegistryErrors } from "./_RegistryL1.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { PrimaryAM } from "../../../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";

/**
 * @notice Fuzz tests for the function "setRiskParametersOfPrimaryAsset" of contract "RegistryL1".
 */
contract SetRiskParametersOfPrimaryAsset_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setRiskParametersOfPrimaryAsset_NonRiskManager(
        address unprivilegedAddress_,
        address asset,
        uint96 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        vm.assume(unprivilegedAddress_ != users.riskManager);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(RegistryErrors.Unauthorized.selector);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
        vm.stopPrank();
    }

    function testFuzz_Revert_setRiskParametersOfPrimaryAsset_CollFactorExceedsLiqFactor(
        address asset,
        uint96 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 1, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, 0, collateralFactor - 1));

        registry_.setAssetModule(asset, address(primaryAM));

        vm.prank(users.riskManager);
        vm.expectRevert(PrimaryAM.CollFactorExceedsLiqFactor.selector);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
    }

    function testFuzz_Success_setRiskParametersOfPrimaryAsset(
        address asset,
        uint96 assetId,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, AssetValuationLib.ONE_4));

        registry_.setAssetModule(asset, address(primaryAM));

        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );

        bytes32 assetKey = bytes32(abi.encodePacked(assetId, asset));
        (, uint112 actualMaxExposure, uint16 actualCollateralFactor, uint16 actualLiquidationFactor) =
            primaryAM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualMaxExposure, maxExposure);
        assertEq(actualCollateralFactor, collateralFactor);
        assertEq(actualLiquidationFactor, liquidationFactor);
    }
}
