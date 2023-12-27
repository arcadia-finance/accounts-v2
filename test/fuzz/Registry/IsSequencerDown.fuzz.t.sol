/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test } from "./_Registry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_isSequencerDown" of contract "Registry".
 */
contract IsSequencerDown_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isSequencerDown_SequencerDown(uint32 gracePeriod, uint32 startedAt, uint32 currentTime)
        public
    {
        // Given: A random time.
        vm.warp(currentTime);

        // And: Sequencer is down.
        sequencerUptimeOracle.setLatestRoundData(1, startedAt);

        // And: A random gracePeriod.
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        // When: "_isSequencerDown()" is called.
        (bool success, bool sequencerDown) = registryExtension.isSequencerDown(address(creditorUsd));

        // Then: Correct variables are returned.
        assertTrue(success);
        assertTrue(sequencerDown);
    }

    function testFuzz_Success_isSequencerDown_GracePeriodNotPassed(
        uint32 gracePeriod,
        uint32 startedAt,
        uint32 currentTime
    ) public {
        // Given: A random time.
        vm.warp(currentTime);

        // And: Sequencer is online.
        startedAt = uint32(bound(startedAt, 0, currentTime));
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        // And: Grace period did not pass.
        vm.assume(currentTime - startedAt < type(uint32).max);
        gracePeriod = uint32(bound(gracePeriod, currentTime - startedAt + 1, type(uint32).max));
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        // When: "_isSequencerDown()" is called.
        (bool success, bool sequencerDown) = registryExtension.isSequencerDown(address(creditorUsd));

        // Then: Correct variables are returned.
        assertTrue(success);
        assertTrue(sequencerDown);
    }

    function testFuzz_Success_isSequencerDown_SequencerUp(uint32 gracePeriod, uint32 startedAt, uint32 currentTime)
        public
    {
        // Given: A random time.
        currentTime = uint32(bound(currentTime, 0, type(uint32).max));
        vm.warp(currentTime);

        // Given: sequencer is back online.
        startedAt = uint32(bound(startedAt, 0, currentTime));
        sequencerUptimeOracle.setLatestRoundData(0, startedAt);

        // And: Grace period did pass.
        gracePeriod = uint32(bound(gracePeriod, 0, currentTime - startedAt));
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        // When: "_isSequencerDown()" is called.
        (bool success, bool sequencerDown) = registryExtension.isSequencerDown(address(creditorUsd));

        // Then: Correct variables are returned.
        assertTrue(success);
        assertFalse(sequencerDown);
    }

    function testFuzz_Success_isSequencerDown_RevertingOracle(uint32 gracePeriod, uint32 currentTime) public {
        // Given: A random time.
        vm.warp(currentTime);

        // And: sequencer oracle will revert.
        sequencerUptimeOracle.setRevertsFlag(true);

        // And: a random gracePeriod.
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        // When: "_isSequencerDown()" is called.
        (bool success, bool sequencerDown) = registryExtension.isSequencerDown(address(creditorUsd));

        // Then: Correct variables are returned.
        assertFalse(success);
        assertFalse(sequencerDown);
    }

    function testFuzz_Success_isSequencerDown_RandomAnswer(
        uint32 gracePeriod,
        uint32 startedAt,
        uint32 currentTime,
        int256 answer
    ) public {
        // Given: A random time.
        currentTime = uint32(bound(currentTime, 0, type(uint32).max));
        vm.warp(currentTime);

        // Given: Oracle outputs random answer, not 0.
        startedAt = uint32(bound(startedAt, 0, currentTime));
        vm.assume(answer != 1);
        sequencerUptimeOracle.setLatestRoundData(answer, startedAt);

        // And: Grace period did pass.
        gracePeriod = uint32(bound(gracePeriod, 0, currentTime - startedAt));
        vm.prank(creditorUsd.riskManager());
        registryExtension.setRiskParameters(address(creditorUsd), 0, gracePeriod, type(uint64).max);

        // When: "_isSequencerDown()" is called.
        (bool success, bool sequencerDown) = registryExtension.isSequencerDown(address(creditorUsd));

        // Then: Correct variables are returned.
        assertTrue(success);
        assertFalse(sequencerDown);
    }
}
