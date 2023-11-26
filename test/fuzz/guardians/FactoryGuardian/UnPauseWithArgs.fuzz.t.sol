/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { FactoryGuardian_Fuzz_Test } from "./_FactoryGuardian.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "unpause" of contract "FactoryGuardian".
 */
contract Unpause_WithArgs_FactoryGuardian_Fuzz_Test is FactoryGuardian_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        FactoryGuardian_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_unpause_OnlyOwner(address nonOwner, bool flag) public {
        vm.assume(nonOwner != users.creatorAddress);

        vm.startPrank(nonOwner);
        vm.expectRevert("UNAUTHORIZED");
        factoryGuardian.unpause(flag);
        vm.stopPrank();
    }

    function testFuzz_Success_unpause(uint256 lastPauseTimestamp, uint256 timePassed, bool initialFlag, bool flag)
        public
    {
        lastPauseTimestamp = bound(lastPauseTimestamp, 32 days + 1, type(uint32).max);
        timePassed = bound(timePassed, 0, type(uint32).max);

        // Given: A random "lastPauseTimestamp".
        vm.warp(lastPauseTimestamp);
        vm.prank(users.guardian);
        factoryGuardian.pause();

        // And: Flags are in random state.
        setFlags(initialFlag);

        // And: Some time passed.
        vm.warp(lastPauseTimestamp + timePassed);

        // When: A "owner" un-pauses.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit PauseFlagsUpdated(initialFlag && flag);
        factoryGuardian.unpause(flag);
        vm.stopPrank();

        // Then: Flags can only be toggled from paused (true) to unpaused (false)
        // if initialFlag was true en new flag is false.
        assertEq(factoryGuardian.createPaused(), initialFlag && flag);
    }
}
