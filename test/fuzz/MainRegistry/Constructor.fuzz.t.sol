/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { MainRegistry } from "../../../src/MainRegistry.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "MainRegistry".
 */
contract Constructor_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment() public {
        vm.startPrank(users.creatorAddress);
        MainRegistry mainRegistry = new MainRegistry(address(factory));
        vm.stopPrank();

        assertEq(mainRegistry.FACTORY(), address(factory));
    }
}
