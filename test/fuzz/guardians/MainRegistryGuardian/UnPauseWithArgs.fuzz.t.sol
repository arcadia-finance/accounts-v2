/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistryGuardian_Fuzz_Test } from "./_MainRegistryGuardian.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "unPause" of contract "MainRegistryGuardian".
 */
contract UnPause_WithArgs_MainRegistryGuardian_Fuzz_Test is MainRegistryGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistryGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_unPause_OnlyOwner(address nonOwner, Flags memory flags) public {
        vm.assume(nonOwner != users.creatorAddress);

        vm.startPrank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        mainRegistryGuardian.unPause(flags.withdrawPaused, flags.depositPaused);
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
        mainRegistryGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlags);

        // And: Some time passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A "owner" un-pauses.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(
            initialFlags.withdrawPaused && flags.withdrawPaused, initialFlags.depositPaused && flags.depositPaused
        );
        mainRegistryGuardian.unPause(flags.withdrawPaused, flags.depositPaused);
        vm.stopPrank();

        // Then: Flags can only be toggled from paused (true) to unpaused (false)
        // if initialFlag was true en new flag is false.
        assertEq(mainRegistryGuardian.withdrawPaused(), initialFlags.withdrawPaused && flags.withdrawPaused);
        assertEq(mainRegistryGuardian.depositPaused(), initialFlags.depositPaused && flags.depositPaused);
    }
}
