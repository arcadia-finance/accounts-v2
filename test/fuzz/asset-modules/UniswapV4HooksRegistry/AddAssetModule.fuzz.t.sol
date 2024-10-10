/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";
import { UniswapV4HooksRegistry } from "../../../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

/**
 * @notice Fuzz tests for the function "AddAssetModule" of contract "UniswapV4HooksRegistry".
 */
contract AddAssetModule_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAssetModule_NotUnique(address assetModule) public {
        // Given: Asset Module is already set
        v4HooksRegistry.setAssetModule(assetModule);

        // When: Calling addAssetModule
        // Then: It should revert
        vm.startPrank(users.owner);
        vm.expectRevert(RegistryErrors.AssetModNotUnique.selector);
        v4HooksRegistry.addAssetModule(assetModule);
        vm.stopPrank();
    }

    function testFuzz_addAssetModule(address assetModule) public {
        // When: Calling addAssetModule
        // Then: It should emit an event
        vm.prank(users.owner);
        vm.expectEmit();
        emit UniswapV4HooksRegistry.AssetModuleAdded(assetModule);
        v4HooksRegistry.addAssetModule(assetModule);

        // And: Asset-Module should be set
        assertEq(v4HooksRegistry.isAssetModule(assetModule), true);
    }
}
