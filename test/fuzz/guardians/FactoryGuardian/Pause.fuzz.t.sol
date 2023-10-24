/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FactoryGuardian_Fuzz_Test } from "./_FactoryGuardian.fuzz.t.sol";

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
        vm.expectRevert("Guardian: Only guardian");
        factoryGuardian.pause();
        vm.stopPrank();
    }

    function testFuzz_Revert_pause_TimeNotExpired(uint256 lastPauseTimestamp, uint256 timePassed) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max);
        timePassed = bound(timePassed, 0, 32 days);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        factoryGuardian.pause();

        // Given: less than 32 days passed
        vm.warp(lastPauseTimestamp + timePassed);

        // When: Guardian pauses again within 32 days passed from the last pause.
        // Then: The transaction reverts with "G_P: Cannot pause".
        vm.startPrank(users.guardian);
        vm.expectRevert("G_P: Cannot pause");
        factoryGuardian.pause();
        vm.stopPrank();
    }

    function testFuzz_Success_pause(uint256 lastPauseTimestamp, uint256 timePassed, Flags memory initialFlags) public {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max - 32 days - 1);
        timePassed = bound(timePassed, 32 days + 1, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        factoryGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlags);

        // Given: More than 32 days passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: the Guardian pauses.
        vm.startPrank(users.guardian);
        vm.expectEmit(true, true, true, true);
        emit PauseUpdate(true, true);
        factoryGuardian.pause();
        vm.stopPrank();

        // Then: All flags are set to True.
        assertTrue(factoryGuardian.createPaused());
        assertTrue(factoryGuardian.liquidatePaused());
    }
}
