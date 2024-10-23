/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { Registry } from "../../../src/Registry.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "Registry".
 */
contract AddAsset_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
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
        registry.addAsset(assetType, asset);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_InvalidAssetType(address asset) public {
        // Given: assetType is zero

        // When: erc20AM calls addAsset
        // Then: addAsset should revert with RegistryErrors.InvalidAssetType.selector
        vm.prank(address(erc20AM));
        vm.expectRevert(RegistryErrors.InvalidAssetType.selector);
        registry.addAsset(0, asset);
    }

    function testFuzz_Revert_addAsset_OverwriteAsset(uint96 assetType) public {
        // Given: assetType is not zero.
        vm.assume(assetType > 0);

        vm.startPrank(address(floorERC721AM));
        // When: floorERC721AM calls addAsset
        // Then: addAsset should revert with RegistryErrors.AssetAlreadyInRegistry.selector
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        registry.addAsset(assetType, address(mockERC20.token1));
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint96 assetType, address newAsset) public {
        // Given: assetType is not zero.
        vm.assume(assetType > 0);

        // And: asset is not yet added.
        vm.assume(registry.inRegistry(newAsset) == false);

        // When: erc20AM calls addAsset with input of address(eth)
        vm.startPrank(address(erc20AM));
        vm.expectEmit();
        emit Registry.AssetAdded(newAsset, address(erc20AM));
        registry.addAsset(assetType, newAsset);
        vm.stopPrank();

        // Then: inRegistry for address(eth) should return true
        assertTrue(registry.inRegistry(newAsset));
        (uint256 assetType_, address assetModule) = registry.assetToAssetInformation(newAsset);
        assertEq(assetType_, assetType);
        assertEq(assetModule, address(erc20AM));
    }
}
