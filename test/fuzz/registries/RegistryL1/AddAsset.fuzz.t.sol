/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL1_Fuzz_Test, RegistryErrors } from "./_RegistryL1.fuzz.t.sol";

import { RegistryL1 } from "../../../../src/registries/RegistryL1.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "RegistryL1".
 */
contract AddAsset_RegistryL1_Fuzz_Test is RegistryL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonAssetModule(address unprivilegedAddress_, uint96 assetType, address asset)
        public
    {
        // Given: unprivilegedAddress_ is not address(erc20AM), address(floorERC721AM) or address(floorERC1155AM)
        vm.assume(unprivilegedAddress_ != address(erc20AM));
        vm.assume(unprivilegedAddress_ != address(floorERC721AM));
        vm.assume(unprivilegedAddress_ != address(floorERC1155AM));
        vm.assume(unprivilegedAddress_ != address(primaryAM));
        vm.assume(unprivilegedAddress_ != address(derivedAM));

        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAsset
        // Then: addAsset should revert with RegistryErrors.OnlyAssetModule.selector
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        registry_.addAsset(assetType, asset);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_InvalidAssetType(address asset) public {
        // Given: assetType is zero

        // When: erc20AM calls addAsset
        // Then: addAsset should revert with RegistryErrors.InvalidAssetType.selector
        vm.prank(address(erc20AM));
        vm.expectRevert(RegistryErrors.InvalidAssetType.selector);
        registry_.addAsset(0, asset);
    }

    function testFuzz_Revert_addAsset_OverwriteAsset2(uint96 assetType) public {
        // Given: assetType is not zero.
        vm.assume(assetType > 0);

        vm.startPrank(address(floorERC721AM));
        // When: floorERC721AM calls addAsset
        // Then: addAsset should revert with RegistryErrors.AssetAlreadyInRegistry.selector
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        registry_.addAsset(assetType, address(mockERC20.token1));
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint96 assetType, address newAsset) public {
        // Given: assetType is not zero.
        vm.assume(assetType > 0);

        // And: asset is not yet added.
        vm.assume(registry_.inRegistry(newAsset) == false);

        // When: erc20AM calls addAsset with input of address(eth)
        vm.startPrank(address(erc20AM));
        vm.expectEmit();
        emit RegistryL1.AssetAdded(newAsset, address(erc20AM));
        registry_.addAsset(assetType, newAsset);
        vm.stopPrank();

        // Then: inRegistry for address(eth) should return true
        assertTrue(registry_.inRegistry(newAsset));
        (uint256 assetType_, address assetModule) = registry_.assetToAssetInformation(newAsset);
        assertEq(assetType_, assetType);
        assertEq(assetModule, address(erc20AM));
    }
}
