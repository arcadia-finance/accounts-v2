/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ChainlinkOM_Fuzz_Test } from "./_ChainlinkOM.fuzz.t.sol";

import { RevertingOracle } from "../../../utils/mocks/oracles/RevertingOracle.sol";

/**
 * @notice Fuzz tests for the function "isActive" of contract "ChainlinkOM".
 */
contract IsActive_ChainlinkOM_Fuzz_Test is ChainlinkOM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ChainlinkOM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_isActive_NotInRegistry(address sender, uint80 oracleId) public {
        // Given: An oracle not added to the "Registry".
        oracleId = uint80(bound(oracleId, registryExtension.getOracleCounter(), type(uint80).max));

        vm.startPrank(sender);
        vm.expectRevert(bytes(""));
        chainlinkOM.isActive(oracleId);
        vm.stopPrank();
    }

    function testFuzz_Success_isActive_RevertingOracle(address sender, uint32 cutOffTime) public {
        RevertingOracle revertingOracle = new RevertingOracle();

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(revertingOracle), "REVERT", "USD", cutOffTime);

        vm.prank(sender);
        assertFalse(chainlinkOM.isActive(oracleId));
    }

    function testFuzz_Success_isActive_ZeroRoundId(address sender, uint32 cutOffTime) public {
        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4", cutOffTime);

        mockOracles.token3ToToken4.setLatestRoundId(0);

        vm.prank(sender);
        assertFalse(chainlinkOM.isActive(oracleId));
    }

    function testFuzz_Success_isActive_NegativeAnswer(address sender, int192 price, uint32 cutOffTime) public {
        price = int192(int256(bound(price, 1, type(int192).max)));
        price = -price;

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4", cutOffTime);

        vm.prank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);

        vm.prank(sender);
        assertFalse(chainlinkOM.isActive(oracleId));
    }

    function testFuzz_Success_isActive_StaleOracle(address sender, int192 price, uint32 timePassed, uint32 cutOffTime)
        public
    {
        price = int192(int256(bound(price, 0, type(int192).max)));
        timePassed = uint32(bound(timePassed, cutOffTime, type(uint32).max));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4", cutOffTime);

        vm.prank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);

        vm.warp(block.timestamp + timePassed);

        vm.prank(sender);
        assertFalse(chainlinkOM.isActive(oracleId));
    }

    function testFuzz_Success_isActive_FuturePrice(address sender, int192 price, uint32 cutOffTime) public {
        price = int192(int256(bound(price, 0, type(int192).max)));
        cutOffTime = uint32(bound(cutOffTime, 1, type(uint32).max));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4", cutOffTime);

        //to not run into an underflow
        vm.warp(uint256(cutOffTime) + 1);

        vm.prank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);

        vm.warp(cutOffTime);

        vm.prank(sender);
        assertFalse(chainlinkOM.isActive(oracleId));
    }

    function testFuzz_Success_isActive_HealthyOracle(address sender, int192 price, uint32 timePassed, uint32 cutOffTime)
        public
    {
        price = int192(int256(bound(price, 0, type(int192).max)));
        cutOffTime = uint32(bound(cutOffTime, 1, type(uint32).max));
        timePassed = uint32(bound(timePassed, 0, cutOffTime - 1));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4", cutOffTime);

        //to not run into an underflow
        vm.warp(cutOffTime);

        vm.prank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);

        vm.warp(block.timestamp + timePassed);

        vm.prank(sender);
        assertTrue(chainlinkOM.isActive(oracleId));
    }

    function testFuzz_Success_isActive_ReactivateOracle(
        address sender,
        int192 price,
        uint32 timePassed,
        uint32 cutOffTime
    ) public {
        price = int192(int256(bound(price, 0, type(int192).max)));
        cutOffTime = uint32(bound(cutOffTime, 1, type(uint32).max));
        timePassed = uint32(bound(timePassed, cutOffTime, type(uint32).max));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(mockOracles.token3ToToken4), "TOKEN3", "TOKEN4", cutOffTime);

        //to not run into an underflow
        vm.warp(cutOffTime);

        vm.prank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);

        vm.warp(block.timestamp + timePassed);

        vm.prank(sender);
        assertFalse(chainlinkOM.isActive(oracleId));

        // Given: Oracle is operating again.
        vm.prank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(price);

        vm.prank(sender);
        assertTrue(chainlinkOM.isActive(oracleId));
    }
}
