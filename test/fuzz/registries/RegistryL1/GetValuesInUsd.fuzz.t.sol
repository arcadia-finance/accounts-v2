/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL1_Fuzz_Test } from "./_RegistryL1.fuzz.t.sol";

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";

/**
 * @notice Fuzz tests for the function "getValuesInUsd" of contract "RegistryL1".
 */
contract GetValuesInUsd_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getValuesInUsd_UnknownAsset(address asset, uint96 assetId, uint256 assetAmount) public {
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

        vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(address(0))));
        registry_.getValuesInUsd(address(creditorUsd), assetAddresses, assetIds, assetAmounts);
    }

    function testFuzz_Success_getValuesInUsd(
        address asset,
        uint96 assetId,
        uint256 assetAmount,
        uint256 usdValue,
        uint112 maxExposure,
        uint16 collateralFactor,
        uint16 liquidationFactor,
        uint32 currentTime
    ) public {
        // Given: oracle staleness-check does not underflow.
        currentTime = uint32(bound(currentTime, 1, type(uint32).max));
        vm.warp(currentTime);

        // And: Risk parameters are set.
        vm.prank(creditorUsd.riskManager());
        registry_.setRiskParameters(address(creditorUsd), 0, type(uint64).max);

        collateralFactor = uint16(bound(collateralFactor, 0, AssetValuationLib.ONE_4));
        liquidationFactor = uint16(bound(liquidationFactor, collateralFactor, AssetValuationLib.ONE_4));

        registry_.setAssetModule(asset, address(primaryAM));
        primaryAM.setUsdValue(usdValue);

        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            registry_.getValuesInUsd(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(valuesAndRiskFactors[0].assetValue, usdValue);
        assertEq(valuesAndRiskFactors[0].collateralFactor, collateralFactor);
        assertEq(valuesAndRiskFactors[0].liquidationFactor, liquidationFactor);
    }

    function testFuzz_Success_getValuesInUsd_BelowMinUsdValue(
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

        registry_.setAssetModule(asset, address(primaryAM));
        primaryAM.setUsdValue(usdValue);

        vm.startPrank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), asset, assetId, maxExposure, collateralFactor, liquidationFactor
        );
        registry_.setRiskParameters(address(creditorUsd), minUsdValue, type(uint64).max);
        vm.stopPrank();

        address[] memory assetAddresses = new address[](1);
        assetAddresses[0] = asset;
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256[] memory assetAmounts = new uint256[](1);
        assetAmounts[0] = assetAmount;

        AssetValueAndRiskFactors[] memory valuesAndRiskFactors =
            registry_.getValuesInUsd(address(creditorUsd), assetAddresses, assetIds, assetAmounts);

        assertEq(valuesAndRiskFactors[0].assetValue, 0);
        assertEq(valuesAndRiskFactors[0].collateralFactor, collateralFactor);
        assertEq(valuesAndRiskFactors[0].liquidationFactor, liquidationFactor);
    }
}
