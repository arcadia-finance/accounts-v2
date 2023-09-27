/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";
import { IPricingModule_New } from "../../../../src/interfaces/IPricingModule_New.sol";

/**
 * @notice Fuzz tests for the "processIndirectDeposit" of contract "FloorERC721PricingModule".
 */
contract ProcessIndirectDeposit_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processIndirectDeposit_NonMainRegistry(address unprivilegedAddress_, uint256 assetId)
        public
    {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC721PricingModule.processIndirectDeposit(address(mockERC721.nft2), assetId, 0, 0);
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_WrongID(uint256 assetId) public {
        vm.assume(assetId > 0); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), 0, 0, oracleNft2ToUsdArr, emptyRiskVarInput_New, 1);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM721_PID: ID not allowed");
        floorERC721PricingModule.processIndirectDeposit(address(mockERC721.nft2), assetId, 0, 0);
        vm.stopPrank();

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 0);
    }

    function testFuzz_Revert_processDirectDeposit_OverExposure(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, 1
        );

        vm.startPrank(address(mainRegistryExtension));
        floorERC721PricingModule.processIndirectDeposit(address(mockERC721.nft2), assetId, 1, 1);

        vm.expectRevert("PM721_PID: Exposure not in limits");
        floorERC721PricingModule.processIndirectDeposit(address(mockERC721.nft2), assetId, 1, 1);
        vm.stopPrank();
    }

    function testFuzz_Success_processIndirectDeposit_positiveDelta(
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        int256 deltaExposureUpperAssetToAsset,
        uint128 maxExposure
    ) public {
        vm.assume(deltaExposureUpperAssetToAsset > 0);
        vm.assume(uint256(deltaExposureUpperAssetToAsset) < maxExposure);
        // To avoid overflow when calculating "usdValueExposureUpperAssetToAsset"
        vm.assume(exposureUpperAssetToAsset < type(uint128).max);

        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, maxExposure
        );

        IPricingModule_New.GetValueInput memory getValueInput = IPricingModule_New.GetValueInput({
            asset: address(mockERC721.nft2),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: UsdBaseCurrencyID
        });

        (uint256 actualValueInUsd,,) = floorERC721PricingModule.getValue(getValueInput);

        vm.assume(actualValueInUsd * exposureUpperAssetToAsset < type(uint256).max);

        vm.prank(address(mainRegistryExtension));
        (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) = floorERC721PricingModule.processIndirectDeposit(
            address(mockERC721.nft2), assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(primaryFlag, true);
        assertEq(usdValueExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, uint256(deltaExposureUpperAssetToAsset));
    }

    /*     function testFuzz_Success_processIndirectDeposit_negativeDelta(uint256 assetId, uint256 exposureUpperAssetToAsset, int256 deltaExposureUpperAssetToAsset, uint128 maxExposure) public {
        vm.assume(assetId != 1);
        vm.assume(assetId != 2);
        vm.assume(assetId != 3);
        vm.assume(deltaExposureUpperAssetToAsset < 0);
        vm.assume(deltaExposureUpperAssetToAsset >= -3);
        // To avoid overflow when calculating "usdValueExposureUpperAssetToAsset"
        vm.assume(exposureUpperAssetToAsset < type(uint128).max);

        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput_New, maxExposure
        );

        floorERC721PricingModule.processDirectDeposit(address(mockERC721.nft2), 1, 1);
        floorERC721PricingModule.processDirectDeposit(address(mockERC721.nft2), 2, 1);
        floorERC721PricingModule.processDirectDeposit(address(mockERC721.nft2), 3, 1);

        IPricingModule_New.GetValueInput memory getValueInput = IPricingModule_New.GetValueInput({
            asset: address(mockERC721.nft2),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: UsdBaseCurrencyID
        });

        (uint256 actualValueInUsd,,) = floorERC721PricingModule.getValue(getValueInput);

        vm.prank(address(mainRegistryExtension));
        (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) = floorERC721PricingModule.processIndirectDeposit(address(mockERC721.nft2), assetId, exposureUpperAssetToAsset, deltaExposureUpperAssetToAsset);

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(primaryFlag, true);
        assertEq(usdValueExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, uint256(deltaExposureUpperAssetToAsset));
    } */
}
