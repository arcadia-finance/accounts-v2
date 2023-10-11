/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, FloorERC721PricingModule_Fuzz_Test } from "./_FloorERC721PricingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "processDirectWithdrawal" of contract "FloorERC721PricingModule".
 */
contract ProcessDirectWithdrawal_FloorERC721PricingModule_Fuzz_Test is FloorERC721PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FloorERC721PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_processDirectWithdrawal_NonMainRegistry(address unprivilegedAddress_) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, type(uint128).max
        );

        vm.assume(unprivilegedAddress_ != address(mainRegistryExtension));

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("APM: ONLY_MAIN_REGISTRY");
        floorERC721PricingModule.processDirectWithdrawal(address(mockERC721.nft2), 1, 1);
        vm.stopPrank();
    }

    function testFuzz_Revert_processDirectWithdrawal_NotOne(uint256 assetId, uint256 amount) public {
        vm.assume(amount != 1); //Not in range
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.startPrank(address(mainRegistryExtension));
        vm.expectRevert("PM721_PDW: Amount not 1");
        floorERC721PricingModule.processDirectWithdrawal(address(mockERC721.nft2), assetId, amount);
        vm.stopPrank();
    }

    function testFuzz_Success_processDirectWithdrawal(uint256 assetId) public {
        vm.prank(users.creatorAddress);
        floorERC721PricingModule.addAsset(
            address(mockERC721.nft2), 0, type(uint256).max, oracleNft2ToUsdArr, emptyRiskVarInput, 1
        );

        vm.prank(address(mainRegistryExtension));
        floorERC721PricingModule.processDirectDeposit(address(mockERC721.nft2), assetId, 1);
        (, uint128 actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 1);

        vm.prank(address(mainRegistryExtension));
        floorERC721PricingModule.processDirectWithdrawal(address(mockERC721.nft2), 1, 1);
        (, actualExposure) = floorERC721PricingModule.exposure(address(mockERC721.nft2));
        assertEq(actualExposure, 0);
    }
}
