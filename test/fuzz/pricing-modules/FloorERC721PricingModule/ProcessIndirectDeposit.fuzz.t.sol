/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";
import { IPricingModule } from "../../../../src/interfaces/IPricingModule.sol";

/**
 * @notice Fuzz tests for the function "processIndirectDeposit" of contract "FloorERC721PricingModule".
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
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput
        );
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, type(uint128).max, 0, 0
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC721PricingModule.processIndirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 0, 0);
        vm.stopPrank();
    }

    function testFuzz_Revert_processIndirectDeposit_WrongID(uint256 assetId) public {
        vm.assume(assetId > 0); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), 0, 0, oracleNft2ToUsdArr, emptyRiskVarInput);
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, 1, 0, 0
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM721_PID: ID not allowed");
        floorERC721PricingModule.processIndirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 0, 0);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721PricingModule.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }

    function testFuzz_Revert_processIndirectDeposit_OverExposure(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput
        );
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, 1, 0, 0
        );

        vm.startPrank(address(mainRegistryExtension));
        floorERC721PricingModule.processIndirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1, 1);

        vm.expectRevert("APPM_PID: Exposure not in limits");
        floorERC721PricingModule.processIndirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1, 1);
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
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput
        );
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, maxExposure, 0, 0
        );

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(mockERC721.nft2),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: UsdBaseCurrencyID,
            creditor: address(creditorUsd)
        });

        (uint256 actualValueInUsd,,) = floorERC721PricingModule.getValue(getValueInput);

        vm.assume(actualValueInUsd * exposureUpperAssetToAsset < type(uint256).max);

        vm.prank(address(mainRegistryExtension));
        (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) = floorERC721PricingModule.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC721.nft2),
            assetId,
            exposureUpperAssetToAsset,
            deltaExposureUpperAssetToAsset
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(primaryFlag, true);
        assertEq(usdValueExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721PricingModule.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, uint256(deltaExposureUpperAssetToAsset));
    }

    function testFuzz_Success_processIndirectDeposit_negativeDelta_NoUnderflow(
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(assetId != 1);
        vm.assume(assetId != 2);
        vm.assume(assetId != 3);
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 1, 3);

        // To avoid overflow when calculating "usdValueExposureUpperAssetToAsset"
        exposureUpperAssetToAsset = bound(exposureUpperAssetToAsset, 0, type(uint128).max);

        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput
        );
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, 3, 0, 0
        );

        vm.startPrank(address(mainRegistryExtension));
        floorERC721PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 1, 1);
        floorERC721PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 2, 1);
        floorERC721PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 3, 1);
        vm.stopPrank();

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(mockERC721.nft2),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: UsdBaseCurrencyID,
            creditor: address(creditorUsd)
        });

        (uint256 actualValueInUsd,,) = floorERC721PricingModule.getValue(getValueInput);

        vm.prank(address(mainRegistryExtension));
        (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) = floorERC721PricingModule.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC721.nft2),
            assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(primaryFlag, true);
        assertEq(usdValueExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721PricingModule.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 3 - deltaExposureUpperAssetToAsset);
    }

    function testFuzz_Success_processIndirectDeposit_negativeDelta_Underflow(
        uint256 assetId,
        uint256 exposureUpperAssetToAsset,
        uint256 deltaExposureUpperAssetToAsset
    ) public {
        vm.assume(assetId != 1);
        vm.assume(assetId != 2);
        vm.assume(assetId != 3);
        deltaExposureUpperAssetToAsset = bound(deltaExposureUpperAssetToAsset, 4, type(uint96).max);

        // To avoid overflow when calculating "usdValueExposureUpperAssetToAsset"
        exposureUpperAssetToAsset = bound(exposureUpperAssetToAsset, 0, type(uint128).max);

        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput
        );
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, 3, 0, 0
        );

        vm.startPrank(address(mainRegistryExtension));
        floorERC721PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 1, 1);
        floorERC721PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 2, 1);
        floorERC721PricingModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), 3, 1);
        vm.stopPrank();

        IPricingModule.GetValueInput memory getValueInput = IPricingModule.GetValueInput({
            asset: address(mockERC721.nft2),
            assetId: 0,
            assetAmount: 1,
            baseCurrency: UsdBaseCurrencyID,
            creditor: address(creditorUsd)
        });

        (uint256 actualValueInUsd,,) = floorERC721PricingModule.getValue(getValueInput);

        vm.prank(address(mainRegistryExtension));
        (bool primaryFlag, uint256 usdValueExposureUpperAssetToAsset) = floorERC721PricingModule.processIndirectDeposit(
            address(creditorUsd),
            address(mockERC721.nft2),
            assetId,
            exposureUpperAssetToAsset,
            -int256(deltaExposureUpperAssetToAsset)
        );

        uint256 expectedUsdValueExposureUpperAssetToAsset = actualValueInUsd * exposureUpperAssetToAsset;
        assertEq(primaryFlag, true);
        assertEq(usdValueExposureUpperAssetToAsset, expectedUsdValueExposureUpperAssetToAsset);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721PricingModule.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }
}
