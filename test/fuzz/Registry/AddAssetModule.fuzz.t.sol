/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { Registry } from "../../../src/Registry.sol";

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
        // Given: unprivilegedAddress_ is not users.owner
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addAssetModule

        // Then: addAssetModule should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        registry.addAssetModule(address(erc20AM));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAssetModule_AddExistingAssetModule() public {
        // Given: All necessary contracts deployed on setup

        // When: users.owner calls addAssetModule for address(erc20AM)
        // Then: addAssetModule should revert with AssetModNotUnique
        vm.prank(users.owner);
        vm.expectRevert(RegistryErrors.AssetModNotUnique.selector);
        registry.addAssetModule(address(erc20AM));
    }

    function testFuzz_Success_addAssetModule(address assetModule) public {
        // Given: assetModule is different from previously deployed asset modules.
        vm.assume(assetModule != address(erc20AM));
        vm.assume(assetModule != address(floorERC721AM));
        vm.assume(assetModule != address(floorERC1155AM));
        vm.assume(assetModule != address(uniV3AM));
        vm.assume(assetModule != address(derivedAM));
        vm.assume(assetModule != address(primaryAM));

        // When: users.owner calls addAssetModule for address(erc20AM)
        vm.startPrank(users.owner);
        vm.expectEmit(true, true, true, true);
        emit Registry.AssetModuleAdded(assetModule);
        registry.addAssetModule(assetModule);
        vm.stopPrank();

        // Then: isAssetModule for address(erc20AM) should return true
        assertTrue(registry.isAssetModule(assetModule));
    }
}
