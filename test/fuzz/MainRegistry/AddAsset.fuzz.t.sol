/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "MainRegistry".
 */
contract AddAsset_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonPricingModule(address unprivilegedAddress_, address asset) public {
        // Given: unprivilegedAddress_ is not address(erc20PricingModule), address(floorERC721PricingModule) or address(floorERC1155PricingModule)
        vm.assume(unprivilegedAddress_ != address(erc20PricingModule));
        vm.assume(unprivilegedAddress_ != address(floorERC721PricingModule));
        vm.assume(unprivilegedAddress_ != address(floorERC1155PricingModule));
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAsset
        // Then: addAsset should revert with "MR: Only PriceMod."
        vm.expectRevert("MR: Only PriceMod.");
        mainRegistryExtension.addAsset(asset, 0);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteAsset() public {
        // Given: erc20PricingModule has token1 added as asset

        vm.startPrank(address(floorERC721PricingModule));
        // When: floorERC721PricingModule calls addAsset
        // Then: addAsset should revert with "MR_AA: Asset already in mainreg"
        vm.expectRevert("MR_AA: Asset already in mainreg");
        mainRegistryExtension.addAsset(address(mockERC20.token1), 0);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_InvalidAssetType(address newAsset, uint256 assetType) public {
        vm.assume(mainRegistryExtension.inMainRegistry(newAsset) == false);
        vm.assume(assetType > type(uint96).max);

        // When: erc20PricingModule calls addAsset with assetType greater than uint96.max
        // Then: addAsset should revert with "MR_AA: Invalid AssetType"
        vm.startPrank(address(erc20PricingModule));
        vm.expectRevert("MR_AA: Invalid AssetType");
        mainRegistryExtension.addAsset(newAsset, assetType);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(address newAsset, uint8 assetType) public {
        vm.assume(mainRegistryExtension.inMainRegistry(newAsset) == false);
        // When: erc20PricingModule calls addAsset with input of address(eth)
        vm.startPrank(address(erc20PricingModule));
        vm.expectEmit(true, true, true, true);
        emit AssetAdded(newAsset, address(erc20PricingModule), assetType);
        mainRegistryExtension.addAsset(newAsset, assetType);
        vm.stopPrank();

        // Then: inMainRegistry for address(eth) should return true
        assertTrue(mainRegistryExtension.inMainRegistry(newAsset));
        (uint96 assetType_, address pricingModule) = mainRegistryExtension.assetToAssetInformation(newAsset);
        assertEq(assetType_, assetType);
        assertEq(pricingModule, address(erc20PricingModule));
    }
}
