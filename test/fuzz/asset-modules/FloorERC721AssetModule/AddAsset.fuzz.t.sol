/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FloorERC721AssetModule_Fuzz_Test } from "./_FloorERC721AssetModule.fuzz.t.sol";

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { FloorERC721AssetModule } from "../../../../src/asset-modules/FloorERC721AssetModule.sol";
import { PrimaryAssetModule } from "../../../../src/asset-modules/AbstractPrimaryAssetModule.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "FloorERC721AssetModule".
 */
contract AddAsset_FloorERC721AssetModule_Fuzz_Test is FloorERC721AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_, uint256 start, uint256 end) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);
    }

    function testFuzz_Revert_addAsset_InvalidRange(uint256 start, uint256 end) public {
        start = bound(start, 1, type(uint256).max);
        end = bound(end, 0, start - 1);

        vm.prank(users.creatorAddress);
        vm.expectRevert(FloorERC721AssetModule.InvalidRange.selector);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);
    }

    function testFuzz_Revert_addAsset_BadOracleSequence(uint256 start, uint256 end) public {
        end = bound(end, start, type(uint256).max);

        bool[] memory badDirection = new bool[](1);
        badDirection[0] = false;
        uint80[] memory oracleNft2ToUsdArr = new uint80[](1);
        oracleNft2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.nft2ToUsd)));
        bytes32 badSequence = BitPackingLib.pack(badDirection, oracleNft2ToUsdArr);

        vm.prank(users.creatorAddress);
        vm.expectRevert(PrimaryAssetModule.BadOracleSequence.selector);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), start, end, badSequence);
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset(uint256 start, uint256 end) public {
        end = bound(end, start, type(uint256).max);

        vm.startPrank(users.creatorAddress);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint256 start, uint256 end, uint256 id) public {
        end = bound(end, start, type(uint256).max);
        id = bound(id, start, end);

        vm.prank(users.creatorAddress);
        floorERC721AssetModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);

        assertTrue(floorERC721AssetModule.inAssetModule(address(mockERC721.nft2)));
        assertTrue(floorERC721AssetModule.isAllowed(address(mockERC721.nft2), id));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint64 assetUnit, bytes32 oracles) = floorERC721AssetModule.assetToInformation(assetKey);
        assertEq(assetUnit, 1);
        assertEq(oracles, oraclesNft2ToUsd);
        (uint256 start_, uint256 end_) = floorERC721AssetModule.getIdRange(address(mockERC721.nft2));
        assertEq(start_, start);
        assertEq(end_, end);

        assertTrue(registryExtension.inRegistry(address(mockERC721.nft2)));
        address assetModule = registryExtension.assetToAssetModule(address(mockERC721.nft2));
        assertEq(assetModule, address(floorERC721AssetModule));
    }
}
