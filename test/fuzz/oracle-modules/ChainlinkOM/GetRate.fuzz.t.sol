/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ChainlinkOM_Fuzz_Test, OracleModule } from "./_ChainlinkOM.fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { RevertingOracle } from "../../../utils/mocks/oracles/RevertingOracle.sol";

/**
 * @notice Fuzz tests for the function "getRate" of contract "ChainlinkOM".
 */
contract GetRate_ChainlinkOM_Fuzz_Test is ChainlinkOM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ChainlinkOM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getRate_NotInRegistry(uint80 oracleId) public {
        // Given: An oracle not added to the "Registry".
        oracleId = uint80(bound(oracleId, registryExtension.getOracleCounter(), type(uint80).max));

        vm.expectRevert(bytes(""));
        chainlinkOM.getRate(oracleId);
    }

    function testFuzz_Revert_getRate_InactiveOracle() public {
        RevertingOracle revertingOracle = new RevertingOracle();

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(revertingOracle), "REVERT", "USD", 2 days);

        vm.expectRevert(OracleModule.InactiveOracle.selector);
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
        uint256 oracleId = chainlinkOM.addOracle(address(oracle), "STABLE1", "USD", 2 days);

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
        uint256 oracleId = chainlinkOM.addOracle(address(oracle), "STABLE1", "USD", 2 days);

        uint256 actualRate = chainlinkOM.getRate(oracleId);

        uint256 expectedRate = rate * 10 ** (18 - decimals);
        assertEq(actualRate, expectedRate);
    }
}
