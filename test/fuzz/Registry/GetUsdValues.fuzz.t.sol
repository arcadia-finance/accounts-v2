/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

import { RiskConstants } from "../../../src/libraries/RiskConstants.sol";
import { RiskModule } from "../../../src/RiskModule.sol";

/**
 * @notice Fuzz tests for the function "getValuesInUsd" of contract "Registry".
 */
contract GetUsdValues_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
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
        vm.assume(asset != address(mockERC20.stable1));
        vm.assume(asset != address(mockERC20.stable2));
        vm.assume(asset != address(mockERC20.token1));
        vm.assume(asset != address(mockERC20.token2));
        vm.assume(asset != address(mockERC721.nft1));
        vm.assume(asset != address(mockERC1155.sft1));

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        vm.expectRevert(bytes(""));
        registryExtension.getValuesInUsd(creditor, assetAddresses, assetIds, assetAmounts);
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

        registryExtension.setAssetModuleForAsset(asset, address(primaryAssetModule));
        primaryAssetModule.setUsdValue(usdValue);

        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            registryExtension.getValuesInUsd(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(valuesAndRiskFactors[0].assetValue, usdValue);
        assertEq(valuesAndRiskFactors[0].collateralFactor, collateralFactor);
        assertEq(valuesAndRiskFactors[0].liquidationFactor, liquidationFactor);
    }

    function testFuzz_Success_getValuesInUsd_BelowMinUsdValue(
        address asset,
        uint96 assetId,
        uint256 assetAmount,
        uint248 usdValue,
        uint256 minUsdValue,
        uint128 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, RiskConstants.RISK_FACTOR_UNIT));
        liquidationFactor = uint16(bound(liquidationFactor, 0, RiskConstants.RISK_FACTOR_UNIT));
        minUsdValue = bound(minUsdValue, uint256(usdValue) + 1, type(uint256).max);

        registryExtension.setAssetModuleForAsset(asset, address(primaryAssetModule));
        primaryAssetModule.setUsdValue(usdValue);

        vm.startPrank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
        registryExtension.setMinUsdValueCreditor(address(creditorUsd), minUsdValue);
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        RiskModule.AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            registryExtension.getValuesInUsd(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(valuesAndRiskFactors[0].assetValue, 0);
        assertEq(valuesAndRiskFactors[0].collateralFactor, collateralFactor);
        assertEq(valuesAndRiskFactors[0].liquidationFactor, liquidationFactor);
    }
}
