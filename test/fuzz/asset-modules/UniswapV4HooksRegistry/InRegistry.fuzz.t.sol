/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";
import { UniswapV4HooksRegistry } from "../../../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

/**
 * @notice Fuzz tests for the function "InRegistry" of contract "UniswapV4HooksRegistry".
 */
contract InRegistry_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_inRegistry_False() public {
        // Given: A hook contract that has the BEFORE and AFTER_REMOVE_LIQUIDITY_FLAG and is not added yet
        address hook = address(unvalidHook);
        // When: Calling inRegistry()
        // Then: It should return "false"
        assertEq(v4HooksRegistry.inRegistry(hook), false);
    }

    function testFuzz_Success_inRegistry_WithFlags() public {
        // Given: A hook contract that has the BEFORE and AFTER_REMOVE_LIQUIDITY_FLAG
        address hook = address(unvalidHook);
        // And: Hook is added to the Registry
        vm.prank(address(uniswapV4AM));
        v4HooksRegistry.addHooks(2, hook);
        // When: Calling inRegistry()
        // Then: It should return "true"
        assertEq(v4HooksRegistry.inRegistry(hook), true);
    }

    function testFuzz_Success_inRegistry_DefaultV4AM() public {
        // Given: A hook contract that does not include BEFORE and AFTER_REMOVE_LIQUIDITY_FLAG
        address hook = address(validHook);
        // When: Calling inRegistry()
        // Then: It should return "true"
        assertEq(v4HooksRegistry.inRegistry(hook), true);
    }
}
