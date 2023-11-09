/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { FactoryGuardian_Fuzz_Test } from "./_FactoryGuardian.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unPause" of contract "FactoryGuardian".
 */
contract UnPause_WithoutArgs_FactoryGuardian_Fuzz_Test is FactoryGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FactoryGuardian_Fuzz_Test.setUp();
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
        factoryGuardian.pause();

        // Given: less than 30 days passed
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A sender un-pauses within 30 days passed from the last pause.
        // Then: The transaction reverts with "G_UP: Cannot unPaus".
        vm.startPrank(sender);
        vm.expectRevert("G_UP: Cannot unPause");
        factoryGuardian.unPause();
        vm.stopPrank();
    }

    function testFuzz_Success_unPause(uint256 lastPauseTimestamp, uint256 timePassed, address sender, bool initialFlag)
        public
    {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max - 30 days - 1);
        timePassed = bound(timePassed, 30 days + 1, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        factoryGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlag);

        // Given: More than 30 days passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A "sender" un-pauses.
        vm.startPrank(sender);
        vm.expectEmit();
        emit PauseUpdate(false);
        factoryGuardian.unPause();
        vm.stopPrank();

        // Then: All flags are set to False.
        assertFalse(factoryGuardian.createPaused());
    }
}
