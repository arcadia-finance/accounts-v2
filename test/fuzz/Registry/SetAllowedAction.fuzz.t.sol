/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "setAllowedAction" of contract "Registry".
 */
contract SetAllowedAction_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setAllowedAction_NonOwner(address action, bool allowed, address nonAuthorized) public {
        vm.assume(nonAuthorized != users.creatorAddress);

        vm.startPrank(nonAuthorized);
        vm.expectRevert("UNAUTHORIZED");
        registryExtension.setAllowedAction(action, allowed);
        vm.stopPrank();
    }

    function testFuzz_Success_setAllowedAction_Owner(address action, bool allowed) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AllowedActionSet(action, allowed);
        registryExtension.setAllowedAction(action, allowed);
        vm.stopPrank();

        assertEq(registryExtension.isActionAllowed(action), allowed);
    }
}
