/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addAssetModule" of contract "Registry".
 */
contract AddAssetModule_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAssetModule_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not users.creatorAddress
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAssetModule

        // Then: addAssetModule should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        registryExtension.addAssetModule(address(erc20AssetModule));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAssetModule_AddExistingAssetModule() public {
        // Given: All necessary contracts deployed on setup

        // When: users.creatorAddress calls addAssetModule for address(erc20AssetModule)
        // Then: addAssetModule should revert with AssetModNotUnique
        vm.prank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.AssetModNotUnique.selector);
        registryExtension.addAssetModule(address(erc20AssetModule));
    }

    function testFuzz_Success_addAssetModule(address assetModule) public {
        // Given: assetModule is different from previously deployed asset modules.
        vm.assume(assetModule != address(erc20AssetModule));
        vm.assume(assetModule != address(floorERC721AM));
        vm.assume(assetModule != address(floorERC1155AM));
        vm.assume(assetModule != address(uniV3AssetModule));
        vm.assume(assetModule != address(derivedAM));
        vm.assume(assetModule != address(primaryAM));

        // When: users.creatorAddress calls addAssetModule for address(erc20AssetModule)
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AssetModuleAdded(assetModule);
        registryExtension.addAssetModule(assetModule);
        vm.stopPrank();

        // Then: isAssetModule for address(erc20AssetModule) should return true
        assertTrue(registryExtension.isAssetModule(assetModule));
    }
}
