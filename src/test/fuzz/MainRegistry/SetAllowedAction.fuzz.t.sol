/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "setAllowedAction" of contract "MainRegistry".
 */
contract SetAllowedAction_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_setAllowedAction_Owner(address action, bool allowed) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AllowedActionSet(action, allowed);
        mainRegistryExtension.setAllowedAction(action, allowed);
        vm.stopPrank();

        assertEq(mainRegistryExtension.isActionAllowed(action), allowed);
    }

    function testRevert_setAllowedAction_NonOwner(address action, bool allowed, address nonAuthorized) public {
        vm.assume(nonAuthorized != users.creatorAddress);

        vm.startPrank(nonAuthorized);
        vm.expectRevert("UNAUTHORIZED");
        mainRegistryExtension.setAllowedAction(action, allowed);
        vm.stopPrank();
    }
}
