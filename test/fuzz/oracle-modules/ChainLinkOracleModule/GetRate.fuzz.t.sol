/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ChainLinkOracleModule_Fuzz_Test } from "./_ChainLinkOracleModule.fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { RevertingOracle } from "../../../utils/mocks/RevertingOracle.sol";

/**
 * @notice Fuzz tests for the function "getRate" of contract "ChainLinkOracleModule".
 */
contract GetRate_ChainLinkOracleModule_Fuzz_Test is ChainLinkOracleModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ChainLinkOracleModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getRate_NotInRegistry(uint80 oracleId) public {
        // Given: An oracle not added to the "MainRegistry".
        oracleId = uint80(bound(oracleId, mainRegistryExtension.getOracleCounter(), type(uint80).max));

        vm.expectRevert("OH_GR: Inactive Oracle");
        chainlinkOM.getRate(oracleId);
    }

    function testFuzz_Revert_getRate_InactiveOracle() public {
        RevertingOracle revertingOracle = new RevertingOracle();

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(revertingOracle), "REVERT", "USD");

        chainlinkOM.decommissionOracle(oracleId);

        vm.expectRevert("OH_GR: Inactive Oracle");
        chainlinkOM.getRate(oracleId);
    }

    function testFuzz_Success_getRate_Overflow(uint8 decimals, uint256 rate) public {
        decimals = uint8(bound(decimals, 0, 17));
        rate = bound(rate, type(uint256).max / 10 ** (18 - decimals) + 1, type(uint256).max);
        vm.assume(rate <= uint256(type(int256).max));

        ArcadiaOracle oracle = new ArcadiaOracle(decimals, "STABLE1 / USD", address(0));
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.prank(users.defaultTransmitter);
        oracle.transmit(int256(rate));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(oracle), "STABLE1", "USD");

        uint256 actualRate = chainlinkOM.getRate(oracleId);
        // Overflows but does not revert.
        assertFalse(actualRate / 10 ** (18 - decimals) == rate);
    }

    function testFuzz_Success_getRate_NoOverflow(uint8 decimals, uint256 rate) public {
        decimals = uint8(bound(decimals, 0, 18));
        rate = bound(rate, 0, type(uint256).max / 10 ** (18 - decimals));
        vm.assume(rate <= uint256(type(int256).max));

        ArcadiaOracle oracle = new ArcadiaOracle(decimals, "STABLE1 / USD", address(0));
        oracle.setOffchainTransmitter(users.defaultTransmitter);
        vm.prank(users.defaultTransmitter);
        oracle.transmit(int256(rate));

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(oracle), "STABLE1", "USD");

        uint256 actualRate = chainlinkOM.getRate(oracleId);

        uint256 expectedRate = rate * 10 ** (18 - decimals);
        assertEq(actualRate, expectedRate);
    }
}
