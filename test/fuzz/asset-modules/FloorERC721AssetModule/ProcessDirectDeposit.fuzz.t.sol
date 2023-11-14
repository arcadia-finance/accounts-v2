/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC721AssetModule_Fuzz_Test } from "./_FloorERC721AssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "FloorERC721AssetModule".
 */
contract ProcessDirectDeposit_FloorERC721AssetModule_Fuzz_Test is FloorERC721AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonMainRegistry(address unprivilegedAddress_, uint256 assetId)
        public
    {
        vm.prank(users.creatorAddress);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("AAM: ONLY_MAIN_REGISTRY");
        floorERC721AssetModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_OverExposure(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, 2, 0, 0
        );

        vm.startPrank(address(mainRegistryExtension));
        floorERC721AssetModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);

        vm.expectRevert("APAM_PDD: Exposure not in limits");
        floorERC721AssetModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_WrongID(uint256 assetId) public {
        vm.assume(assetId > 1); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), 0, 1, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, 1, 0, 0
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("AM721_PDD: Asset not allowed");
        floorERC721AssetModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721AssetModule.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }

    function testFuzz_Success_processDirectDeposit(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        mainRegistryExtension.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft2), 0, 2, 0, 0
        );

        vm.prank(address(mainRegistryExtension));
        floorERC721AssetModule.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721AssetModule.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 1);
    }
}
