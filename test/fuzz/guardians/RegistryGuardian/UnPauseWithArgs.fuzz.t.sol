/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { RegistryGuardian_Fuzz_Test } from "./_RegistryGuardian.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unPause" of contract "RegistryGuardian".
 */
contract UnPause_WithArgs_RegistryGuardian_Fuzz_Test is RegistryGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_unPause_OnlyOwner(address nonOwner, Flags memory flags) public {
        vm.assume(nonOwner != users.creatorAddress);

        vm.startPrank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        registryGuardian.unpause(flags.withdrawPaused, flags.depositPaused);
        vm.stopPrank();
    }

    function testFuzz_Success_unPause(
        uint256 lastPauseTimestamp,
        uint256 timePassed,
        Flags memory initialFlags,
        Flags memory flags
    ) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max);
        timePassed = bound(timePassed, 0, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        registryGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlags);

        // And: Some time passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A "owner" un-pauses.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit PauseFlagsUpdated(
            initialFlags.withdrawPaused && flags.withdrawPaused, initialFlags.depositPaused && flags.depositPaused
        );
        registryGuardian.unpause(flags.withdrawPaused, flags.depositPaused);
        vm.stopPrank();

        // Then: Flags can only be toggled from paused (true) to unpaused (false)
        // if initialFlag was true en new flag is false.
        assertEq(registryGuardian.withdrawPaused(), initialFlags.withdrawPaused && flags.withdrawPaused);
        assertEq(registryGuardian.depositPaused(), initialFlags.depositPaused && flags.depositPaused);
    }
}
