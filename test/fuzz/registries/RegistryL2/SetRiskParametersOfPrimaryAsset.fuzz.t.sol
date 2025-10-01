/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryL2_Fuzz_Test } from "./_RegistryL2.fuzz.t.sol";

import { AssetValuationLib } from "../../../../src/libraries/AssetValuationLib.sol";
import { PrimaryAM } from "../../../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";

/**
 * @notice Fuzz tests for the function "setRiskParametersOfPrimaryAsset" of contract "RegistryL2".
 */
contract SetRiskParametersOfPrimaryAsset_RegistryL2_Fuzz_Test is RegistryL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL2_Fuzz_Test.setUp();
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
        registry.setRiskParametersOfPrimaryAsset(
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

        registry.setAssetModule(asset, address(primaryAM));

        vm.prank(users.riskManager);
        vm.expectRevert(PrimaryAM.CollFactorExceedsLiqFactor.selector);
        registry.setRiskParametersOfPrimaryAsset(
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

        registry.setAssetModule(asset, address(primaryAM));

        vm.prank(users.riskManager);
        registry.setRiskParametersOfPrimaryAsset(
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
