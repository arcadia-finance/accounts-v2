/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./FloorERC721PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processDeposit" of contract "FloorERC721PricingModule".
 */
contract ProcessDeposit_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_processDeposit_NonMainRegistry(address unprivilegedAddress_, uint256 assetId, address account)
        public
    {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC721PricingModule.processDeposit(account, address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();
    }

    function testRevert_processDeposit_OverExposure(uint256 assetId, address account) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.startPrank(address(mainRegistryExtension));
        floorERC721PricingModule.processDeposit(account, address(mockERC721.nft2), assetId, 1);

        vm.expectRevert("PM721_PD: Exposure not in limits");
        floorERC721PricingModule.processDeposit(account, address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();
    }

    function testRevert_processDeposit_WrongID(uint256 assetId, address account) public {
        vm.assume(assetId > 0); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(address(mockERC721.nft2), 0, 0, oracleNft2ToUsdArr, emptyRiskVarInput, 1);

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM721_PD: ID not allowed");
        floorERC721PricingModule.processDeposit(account, address(mockERC721.nft2), assetId, 1);
        vm.stopPrank();

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 0);
    }

    function testRevert_processDeposit_NotOne(uint256 assetId, address account, uint256 amount) public {
        vm.assume(amount != 1); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM721_PD: Amount not 1");
        floorERC721PricingModule.processDeposit(account, address(mockERC721.nft2), assetId, amount);
        vm.stopPrank();

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 0);
    }

    function testSuccess_processDeposit_Positive(uint256 assetId, address account) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.prank(address(mainRegistryExtension));
        floorERC721PricingModule.processDeposit(account, address(mockERC721.nft2), assetId, 1);

        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 1);
    }
}
