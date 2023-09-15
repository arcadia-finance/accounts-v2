/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processWithdrawal" of contract "FloorERC721PricingModule".
 */
contract ProcessWithdrawal_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_processWithdrawal_NonMainRegistry(address unprivilegedAddress_, address account_) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC721PricingModule.processWithdrawal(account_, address(mockERC721.nft2), 1, 1);
        vm.stopPrank();
    }

    function testRevert_processWithdrawal_NotOne(uint256 assetId, address account_, uint256 amount) public {
        vm.assume(amount != 1); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM721_PW: Amount not 1");
        floorERC721PricingModule.processWithdrawal(account_, address(mockERC721.nft2), assetId, amount);
        vm.stopPrank();
    }

    function testSuccess_processWithdrawal(uint256 assetId, address account_) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.prank(address(mainRegistryExtension));
        floorERC721PricingModule.processDeposit(account_, address(mockERC721.nft2), assetId, 1);
        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 1);

        vm.prank(address(mainRegistryExtension));
        floorERC721PricingModule.processWithdrawal(account_, address(mockERC721.nft2), 1, 1);
        (, actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 0);
    }
}
