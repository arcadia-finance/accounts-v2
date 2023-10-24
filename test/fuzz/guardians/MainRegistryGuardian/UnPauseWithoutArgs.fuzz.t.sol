/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { MainRegistryGuardian_Fuzz_Test } from "./_MainRegistryGuardian.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unPause" of contract "MainRegistryGuardian".
 */
contract UnPause_WithoutArgs_MainRegistryGuardian_Fuzz_Test is MainRegistryGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistryGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_unPause_TimeNotExpired(uint256 lastPauseTimestamp, uint256 timePassed, address sender)
        public
    {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max);
        timePassed = bound(timePassed, 0, 30 days);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        mainRegistryGuardian.pause();

        // Given: less than 30 days passed
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A sender un-pauses within 30 days passed from the last pause.
        // Then: The transaction reverts with "G_UP: Cannot unPaus".
        vm.startPrank(sender);
        vm.expectRevert("G_UP: Cannot unPause");
        mainRegistryGuardian.unPause();
        vm.stopPrank();
    }

    function testFuzz_Success_unPause(
        uint256 lastPauseTimestamp,
        uint256 timePassed,
        address sender,
        Flags memory initialFlags
    ) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max - 30 days - 1);
        timePassed = bound(timePassed, 30 days + 1, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        mainRegistryGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlags);

        // Given: More than 30 days passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A "sender" un-pauses.
        vm.startPrank(sender);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(false, false);
        mainRegistryGuardian.unPause();
        vm.stopPrank();

        // Then: All flags are set to False.
        assertFalse(mainRegistryGuardian.withdrawPaused());
        assertFalse(mainRegistryGuardian.depositPaused());
    }
}
