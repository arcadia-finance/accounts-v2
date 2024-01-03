/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FactoryGuardian_Fuzz_Test } from "./_FactoryGuardian.fuzz.t.sol";

import { GuardianErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "pause" of contract "FactoryGuardian".
 */
contract Pause_FactoryGuardian_Fuzz_Test is FactoryGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FactoryGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_pause_OnlyGuard(address nonGuard) public {
        vm.assume(nonGuard != users.guardian);

        vm.startPrank(nonGuard);
        vm.expectRevert(GuardianErrors.OnlyGuardian.selector);
        factoryGuardian.pause();
        vm.stopPrank();
    }

    function testFuzz_Success_pause(uint256 lastPauseTimestamp, uint256 timePassed, bool flag) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 0, type(uint32).max);
        timePassed = bound(timePassed, 0, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        factoryGuardian.pause();

        // And: Flags are in random state.
        setFlags(flag);

        // Given: a random time passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: the Guardian pauses.
        vm.startPrank(users.guardian);
        vm.expectEmit();
        emit PauseFlagsUpdated(true);
        factoryGuardian.pause();
        vm.stopPrank();

        // Then: All flags are set to True.
        assertTrue(factoryGuardian.createPaused());
    }
}
