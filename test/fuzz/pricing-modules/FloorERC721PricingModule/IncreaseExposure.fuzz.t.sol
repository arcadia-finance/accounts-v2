/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "increaseExposure" of contract "FloorERC721PricingModule".
 */
contract IncreaseExposure_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_increaseExposure_NonMainRegistry(address unprivilegedAddress_, uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC721PricingModule.increaseExposure(address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_increaseExposure_OverExposure(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.startPrank(address(mainRegistryExtension));
        floorERC721PricingModule.increaseExposure(address(mockERC721.nft2), assetId, 1);

        vm.expectRevert("PM721_IE: Exposure not in limits");
        floorERC721PricingModule.increaseExposure(address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_increaseExposure_WrongID(uint256 assetId) public {
        vm.assume(assetId > 0); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), 0, 0, oracleNft2ToUsdArr, emptyRiskVarInput, 1);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM721_IE: ID not allowed");
        floorERC721PricingModule.increaseExposure(address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 0);
    }

    function testFuzz_Revert_increaseExposure_NotOne(uint256 assetId, uint256 amount) public {
        vm.assume(amount != 1); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM721_IE: Amount not 1");
        floorERC721PricingModule.increaseExposure(address(mockERC721.nft2), assetId, amount);
        vm.stopPrank();

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 0);
    }

    function testFuzz_Success_increaseExposure_Positive(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.prank(address(mainRegistryExtension));
        floorERC721PricingModule.increaseExposure(address(mockERC721.nft2), assetId, 1);

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 1);
    }
}
