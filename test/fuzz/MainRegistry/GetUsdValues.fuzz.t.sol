/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { RiskConstants } from "../../../src/libraries/RiskConstants.sol";
import { RiskModule } from "../../../src/RiskModule.sol";

/**
 * @notice Fuzz tests for the function "getValuesInUsd" of contract "MainRegistry".
 */
contract GetUsdValues_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValuesInUsd_UnknownAsset(
        address creditor,
        address asset,
        uint96 assetId,
        uint256 assetAmount
    ) public {
        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        vm.expectRevert(bytes(""));
        mainRegistryExtension.getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getValuesInUsd(
        address asset,
        uint96 assetId,
        uint256 assetAmount,
        uint256 usdValue,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, RiskConstants.RISK_FACTOR_UNIT));
        liquidationFactor = uint16(bound(liquidationFactor, 0, RiskConstants.RISK_FACTOR_UNIT));

        mainRegistryExtension.setPricingModuleForAsset(asset, address(primaryPricingModule));
        primaryPricingModule.setUsdValue(usdValue);

        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            mainRegistryExtension.getValuesInUsd(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(valuesAndRiskFactors[0].assetValue, usdValue);
        assertEq(valuesAndRiskFactors[0].collateralFactor, collateralFactor);
        assertEq(valuesAndRiskFactors[0].liquidationFactor, liquidationFactor);
    }
}
