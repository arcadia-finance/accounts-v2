/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";
import { UniswapV4HooksRegistry } from "../../../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

/**
 * @notice Fuzz tests for the function "AddHooks" of contract "UniswapV4HooksRegistry".
 */
contract AddHooks_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addHooks_InvalidAssetType(uint96 assetType, address hooks) public {
        // Given: Asset type != 2
        vm.assume(assetType != 2);

        // When: Calling addHooks
        // Then: It should revert
        vm.startPrank(address(uniswapV4AM));
        vm.expectRevert(RegistryErrors.InvalidAssetType.selector);
        v4HooksRegistry.addHooks(assetType, hooks);
        vm.stopPrank();
    }

    function testFuzz_revert_addHooks_AssetAlreadyInRegistry() public {
        // When: Calling addHooks
        // Then: It should revert
        vm.startPrank(address(uniswapV4AM));
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        v4HooksRegistry.addHooks(2, address(validHook));
        vm.stopPrank();
    }

    function testFuzz_success_addHooks() public {
        // Given: Hook address that has not been added yet
        address newHook = address(unvalidHook);

        // When: Calling addHooks
        // Then: It should revert
        vm.startPrank(address(uniswapV4AM));
        vm.expectEmit();
        emit UniswapV4HooksRegistry.HooksAdded(newHook, address(uniswapV4AM));
        v4HooksRegistry.addHooks(2, address(newHook));
        vm.stopPrank();

        // And: Values should be set
        assertEq(v4HooksRegistry.inRegistry(newHook), true);
        assertEq(v4HooksRegistry.hooksToAssetModule(newHook), address(uniswapV4AM));
    }
}
