/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "isAllowed" of contract "FloorERC721PricingModule".
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
    function testFuzz_Success_isAllowed_Positive() public {
        // Given: All necessary contracts deployed on setup
        vm.prank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, 9999, oracleNft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        // Then: address(mockERC721.nft2) should return true on isAllowed for id's 0 to 9999
        assertTrue(floorERC721PricingModule.isAllowed(address(mockERC721.nft2), 0));
        assertTrue(floorERC721PricingModule.isAllowed(address(mockERC721.nft2), 9999));
        assertTrue(floorERC721PricingModule.isAllowed(address(mockERC721.nft2), 5000));
    }

    function testFuzz_Success_isAllowed_NegativeWrongAddress(address randomAsset) public {
        // Given: All necessary contracts deployed on setup
        // When: input is randomAsset

        // Then: isAllowed for randomAsset should return false
        assertFalse(floorERC721PricingModule.isAllowed(randomAsset, 0));
    }

    function testFuzz_Success_isAllowed_NegativeIdOutsideRange(uint256 id) public {
        // Given: id is lower than 10 or bigger than 1000
        vm.assume(id < 10 || id > 1000);
        vm.prank(users.creatorAddress);
        // When: users.creatorAddress calls addAsset
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 10, 999, oracleNft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        // Then: isAllowed for address(mockERC721.nft2) should return false
        assertFalse(floorERC721PricingModule.isAllowed(address(mockERC721.nft2), id));
    }
}
