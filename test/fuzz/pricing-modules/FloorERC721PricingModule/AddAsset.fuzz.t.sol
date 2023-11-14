/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { PricingModule } from "../../../../src/pricing-modules/AbstractPricingModule.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "FloorERC721PricingModule".
 */
contract AddAsset_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_, uint256 start, uint256 end) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);
    }

    function testFuzz_Revert_addAsset_InvalidRange(uint256 start, uint256 end) public {
        start = bound(start, 1, type(uint256).max);
        end = bound(end, 0, start - 1);

        vm.prank(users.creatorAddress);
        vm.expectRevert("PM721_AA: Invalid Range");
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);
    }

    function testFuzz_Revert_addAsset_BadOracleSequence(uint256 start, uint256 end) public {
        end = bound(end, start, type(uint256).max);

        bool[] memory badDirection = new bool[](1);
        badDirection[0] = false;
        uint80[] memory oracleNft2ToUsdArr = new uint80[](1);
        oracleNft2ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.nft2ToUsd)));
        bytes32 badSequence = BitPackingLib.pack(badDirection, oracleNft2ToUsdArr);

        vm.prank(users.creatorAddress);
        vm.expectRevert("PM721_AA: Bad Sequence");
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), start, end, badSequence);
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset(uint256 start, uint256 end) public {
        end = bound(end, start, type(uint256).max);

        vm.startPrank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);
        vm.expectRevert("MR_AA: Asset already in mainreg");
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint256 start, uint256 end, uint256 id) public {
        end = bound(end, start, type(uint256).max);
        id = bound(id, start, end);

        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), start, end, oraclesNft2ToUsd);

        assertTrue(floorERC721PricingModule.inPricingModule(address(mockERC721.nft2)));
        assertTrue(floorERC721PricingModule.isAllowed(address(mockERC721.nft2), id));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(mockERC721.nft2)));
        (uint64 assetUnit, bytes32 oracles) = floorERC721PricingModule.assetToInformation(assetKey);
        assertEq(assetUnit, 1);
        assertEq(oracles, oraclesNft2ToUsd);
        (uint256 start_, uint256 end_) = floorERC721PricingModule.getIdRange(address(mockERC721.nft2));
        assertEq(start_, start);
        assertEq(end_, end);

        assertTrue(mainRegistryExtension.inMainRegistry(address(mockERC721.nft2)));
        (uint96 assetType_, address pricingModule) =
            mainRegistryExtension.assetToAssetInformation(address(mockERC721.nft2));
        assertEq(assetType_, 1);
        assertEq(pricingModule, address(floorERC721PricingModule));
    }
}
