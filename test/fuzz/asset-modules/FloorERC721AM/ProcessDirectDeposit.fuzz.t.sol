/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC721AM_Fuzz_Test, AssetModule } from "./_FloorERC721AM.fuzz.t.sol";

import { FloorERC721AM } from "../../../utils/mocks/asset-modules/FloorERC721AM.sol";

/**
 * @notice Fuzz tests for the function "processDirectDeposit" of contract "FloorERC721AM".
 */
contract ProcessDirectDeposit_FloorERC721AM_Fuzz_Test is FloorERC721AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectDeposit_NonRegistry(address unprivilegedAddress_, uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);

        vm.assume(unprivilegedAddress_ != address(registryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert(AssetModule.OnlyRegistry.selector);
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_OverExposure(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC721.nft2), 0, 2, 0, 0);

        vm.startPrank(address(registryExtension));
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);

        vm.expectRevert(AssetModule.ExposureNotInLimits.selector);
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectDeposit_WrongID(uint256 assetId) public {
        vm.assume(assetId > 1); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, 1, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC721.nft2), 0, 1, 0, 0);

        vm.startPrank(address(registryExtension));
        vm.expectRevert(FloorERC721AM.AssetNotAllowed.selector);
        floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 0);
    }

    function testFuzz_Success_processDirectDeposit(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721AM.addAsset(address(mockERC721.nft2), 0, type(uint256).max, oraclesNft2ToUsd);
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(address(creditorUsd), address(mockERC721.nft2), 0, 2, 0, 0);

        vm.prank(address(registryExtension));
        (uint256 recursiveCalls, uint256 assetType) =
            floorERC721AM.processDirectDeposit(address(creditorUsd), address(mockERC721.nft2), assetId, 1);

        assertEq(recursiveCalls, 1);
        assertEq(assetType, 1);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint128 actualExposure,,,) = floorERC721AM.riskParams(address(creditorUsd), assetKey);
        assertEq(actualExposure, 1);
    }
}
