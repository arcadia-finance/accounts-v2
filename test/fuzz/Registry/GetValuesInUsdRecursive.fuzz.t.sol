/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getValuesInUsdRecursive" of contract "Registry".
 */
contract GetValuesInUsdRecursive_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValuesInUsdRecursive_UnknownAsset(
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
        registryExtension.getValuesInUsdRecursive(creditor, assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getValuesInUsdRecursive(
        address asset,
        uint96 assetId,
        uint256 assetAmount,
        uint128 usdValue,
        uint128 minUsdValue,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor
    ) public {
        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, AssetValuationLib.ONE_4));
        usdValue = uint128(bound(usdValue, 0, type(uint128).max - 1));
        minUsdValue = uint128(bound(minUsdValue, usdValue + 1, type(uint128).max));

        registryExtension.setAssetToAssetModule(asset, address(primaryAM));
        primaryAM.setUsdValue(usdValue);

        vm.startPrank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
        registryExtension.setRiskParameters(address(creditorUsd), minUsdValue, 0, type(uint64).max);
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            registryExtension.getValuesInUsdRecursive(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(valuesAndRiskFactors[0].assetValue, usdValue);
        assertEq(valuesAndRiskFactors[0].collateralFactor, collateralFactor);
        assertEq(valuesAndRiskFactors[0].liquidationFactor, liquidationFactor);
    }
}
