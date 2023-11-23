/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ChainlinkOracleModule_Fuzz_Test } from "./_ChainlinkOracleModule.fuzz.t.sol";

import { RevertingOracle } from "../../../utils/mocks/RevertingOracle.sol";

/**
 * @notice Fuzz tests for the function "decommissionOracle" of contract "ChainlinkOracleModule".
 */
contract DecommissionOracle_ChainlinkOracleModule_Fuzz_Test is ChainlinkOracleModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ChainlinkOracleModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_decommissionOracle_NotInRegistry(address sender, uint80 oracleId) public {
        // Given: An oracle not added to the "Registry".
        oracleId = uint80(bound(oracleId, registryExtension.getOracleCounter(), type(uint80).max));

        vm.startPrank(sender);
        vm.expectRevert(bytes(""));
        chainlinkOM.decommissionOracle(oracleId);
        vm.stopPrank();
    }

    function testFuzz_Success_decommissionOracle_RevertingOracle(address sender) public {
        RevertingOracle revertingOracle = new RevertingOracle();

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(revertingOracle), "REVERT", "USD");

        vm.prank(sender);
        assertFalse(chainlinkOM.decommissionOracle(oracleId));

        (bool isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertFalse(isActive);
    }

    function testFuzz_Success_decommissionOracle_AnswerTooLow(
        address sender,
        int192 minAnswer,
        int192 maxAnswer,
        int192 price
    ) public {
        minAnswer = int192(int256(bound(minAnswer, 0, type(int192).max)));
        maxAnswer = int192(int256(bound(maxAnswer, minAnswer, type(int192).max)));
        price = int192(int256(bound(price, 0, minAnswer)));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4");

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);
        mockOracles.token3ToToken4.setMinAnswer(minAnswer);
        mockOracles.token3ToToken4.setMaxAnswer(maxAnswer);
        vm.stopPrank();

        (bool isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertTrue(isActive);

        vm.prank(sender);
        assertFalse(chainlinkOM.decommissionOracle(oracleId));

        (isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertFalse(isActive);
    }

    function testFuzz_Success_decommissionOracle_AnswerTooHigh(
        address sender,
        int192 minAnswer,
        int192 maxAnswer,
        int192 price
    ) public {
        minAnswer = int192(int256(bound(minAnswer, 0, type(int192).max)));
        maxAnswer = int192(int256(bound(maxAnswer, minAnswer, type(int192).max)));
        price = int192(int256(bound(price, maxAnswer, type(int192).max)));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4");

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);
        mockOracles.token3ToToken4.setMinAnswer(minAnswer);
        mockOracles.token3ToToken4.setMaxAnswer(maxAnswer);
        vm.stopPrank();

        (bool isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertTrue(isActive);

        vm.prank(sender);
        assertFalse(chainlinkOM.decommissionOracle(oracleId));

        (isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertFalse(isActive);
    }

    function testFuzz_Success_decommissionOracle_UpdatedAtTooOld(
        address sender,
        int192 minAnswer,
        int192 maxAnswer,
        int192 price,
        uint32 timePassed
    ) public {
        minAnswer = int192(int256(bound(minAnswer, 0, type(int192).max - 2)));
        maxAnswer = int192(int256(bound(maxAnswer, minAnswer + 2, type(int192).max)));
        price = int192(int256(bound(price, minAnswer + 1, maxAnswer - 1)));

        timePassed = uint32(bound(timePassed, 2 days + 1, type(uint32).max));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4");

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);
        mockOracles.token3ToToken4.setMinAnswer(minAnswer);
        mockOracles.token3ToToken4.setMaxAnswer(maxAnswer);
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);

        (bool isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertTrue(isActive);

        vm.prank(sender);
        assertFalse(chainlinkOM.decommissionOracle(oracleId));

        (isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertFalse(isActive);
    }

    function testFuzz_Success_decommissionOracle_HealthyOracle(
        address sender,
        int192 minAnswer,
        int192 maxAnswer,
        int192 price,
        uint32 timePassed
    ) public {
        minAnswer = int192(int256(bound(minAnswer, 0, type(int192).max - 2)));
        maxAnswer = int192(int256(bound(maxAnswer, minAnswer + 2, type(int192).max)));
        price = int192(int256(bound(price, minAnswer + 1, maxAnswer - 1)));

        timePassed = uint32(bound(timePassed, 0, 2 days));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4");

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);
        mockOracles.token3ToToken4.setMinAnswer(minAnswer);
        mockOracles.token3ToToken4.setMaxAnswer(maxAnswer);
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);

        (bool isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertTrue(isActive);

        vm.prank(sender);
        assertTrue(chainlinkOM.decommissionOracle(oracleId));

        (isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertTrue(isActive);
    }

    function testFuzz_Success_decommissionOracle_ReactivateOracle(
        address sender,
        int192 minAnswer,
        int192 maxAnswer,
        int192 price,
        uint32 timePassed
    ) public {
        minAnswer = int192(int256(bound(minAnswer, 0, type(int192).max - 2)));
        maxAnswer = int192(int256(bound(maxAnswer, minAnswer + 2, type(int192).max)));
        price = int192(int256(bound(price, minAnswer + 1, maxAnswer - 1)));

        timePassed = uint32(bound(timePassed, 2 days + 1, type(uint32).max));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4");

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);
        mockOracles.token3ToToken4.setMinAnswer(minAnswer);
        mockOracles.token3ToToken4.setMaxAnswer(maxAnswer);
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);

        (bool isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertTrue(isActive);

        vm.prank(sender);
        assertFalse(chainlinkOM.decommissionOracle(oracleId));

        (isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertFalse(isActive);

        // Given: Oracle is operating again.
        vm.prank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);

        vm.prank(sender);
        assertTrue(chainlinkOM.decommissionOracle(oracleId));

        (isActive,,) = chainlinkOM.getOracleInformation(oracleId);
        assertTrue(isActive);
    }
}
