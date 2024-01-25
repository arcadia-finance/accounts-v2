/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { RegistryGuardian_Fuzz_Test } from "./_RegistryGuardian.fuzz.t.sol";

import { GuardianErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "unPause" of contract "RegistryGuardian".
 */
contract UnPause_WithoutArgs_RegistryGuardian_Fuzz_Test is RegistryGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryGuardian_Fuzz_Test.setUp();
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
        registryGuardian.pause();

        // Given: less than 30 days passed
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A sender un-pauses within 30 days passed from the last pause.
        // Then: The transaction reverts with "G_UP: Cannot unPaus".
        vm.startPrank(sender);
        vm.expectRevert(GuardianErrors.CoolDownPeriodNotPassed.selector);
        registryGuardian.unpause();
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
        registryGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlags);

        // Given: More than 30 days passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A "sender" un-pauses.
        vm.startPrank(sender);
        vm.expectEmit(true, true, true, true);
        emit PauseFlagsUpdated(false, initialFlags.depositPaused);
        registryGuardian.unpause();
        vm.stopPrank();

        // Then: All flags are set to False.
        assertFalse(registryGuardian.withdrawPaused());
        assertEq(registryGuardian.depositPaused(), initialFlags.depositPaused);
    }
}
