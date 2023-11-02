/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "FloorERC721PricingModule".
 */
contract IsAllowed_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Positive(uint96 assetId, uint96 idRangeStart, uint96 idRangeEnd) public {
        idRangeEnd = uint96(bound(idRangeEnd, idRangeStart, type(uint96).max));
        assetId = uint96(bound(assetId, idRangeStart, idRangeEnd));

        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), idRangeStart, idRangeEnd, oracleNft2ToUsdArr);

        assertTrue(floorERC721PricingModule.isAllowed(address(mockERC721.nft2), assetId));
    }

    function testFuzz_Success_isAllowed_Negative_WrongAddress(address randomAsset) public {
        assertFalse(floorERC721PricingModule.isAllowed(randomAsset, 0));
    }

    function testFuzz_Success_isAllowed_Negative_IdBelowRange(uint96 assetId, uint96 idRangeStart, uint96 idRangeEnd)
        public
    {
        idRangeStart = uint96(bound(idRangeStart, 1, type(uint96).max));
        idRangeEnd = uint96(bound(idRangeEnd, idRangeStart, type(uint96).max));
        assetId = uint96(bound(assetId, 0, idRangeStart - 1));

        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), idRangeStart, idRangeEnd, oracleNft2ToUsdArr);

        assertFalse(floorERC721PricingModule.isAllowed(address(mockERC721.nft2), assetId));
    }

    function testFuzz_Success_isAllowed_Negative_IdAboveRange(uint96 assetId, uint96 idRangeStart, uint96 idRangeEnd)
        public
    {
        idRangeStart = uint96(bound(idRangeStart, 0, type(uint96).max - 1));
        idRangeEnd = uint96(bound(idRangeEnd, idRangeStart, type(uint96).max - 1));
        assetId = uint96(bound(assetId, idRangeEnd + 1, type(uint96).max));

        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), idRangeStart, idRangeEnd, oracleNft2ToUsdArr);

        assertFalse(floorERC721PricingModule.isAllowed(address(mockERC721.nft2), assetId));
    }
}
