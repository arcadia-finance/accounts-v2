/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryL2_Fuzz_Test } from "./_RegistryL2.fuzz.t.sol";

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { OracleModuleMock } from "../../../utils/mocks/oracle-modules/OracleModuleMock.sol";

/**
 * @notice Fuzz tests for the function "getRateInUsd" of contract "RegistryL2".
 */
contract GetRateInUsd_RegistryL2_Fuzz_Test is RegistryL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        RegistryL2_Fuzz_Test.setUp();

        oracleModule = new OracleModuleMock(users.owner, address(registry));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_getRateInUsd_BaseAssetToQuoteAsset_Overflow(uint80 oracleId, uint256 rate) public {
        rate = bound(rate, type(uint256).max / 1e18 + 1, type(uint256).max);

        addMockedOracle(oracleId, rate, bytes16("A"), bytes16("USD"), true);

        uint80[] memory oraclesIds = new uint80[](1);
        oraclesIds[0] = oracleId;
        bool[] memory baseToQuoteAsset = new bool[](1);
        baseToQuoteAsset[0] = true;
        bytes32 oracleSequence = BitPackingLib.pack(baseToQuoteAsset, oraclesIds);

        vm.expectRevert(bytes(""));
        registry.getRateInUsd(oracleSequence);
    }

    function testFuzz_Success_getRateInUsd_BaseAssetToQuoteAsset(uint80 oracleId, uint256 rate) public {
        rate = bound(rate, 0, type(uint256).max / 1e18);

        addMockedOracle(oracleId, rate, bytes16("A"), bytes16("USD"), true);

        uint256 expectedRate = rate;

        uint80[] memory oraclesIds = new uint80[](1);
        oraclesIds[0] = oracleId;
        bool[] memory baseToQuoteAsset = new bool[](1);
        baseToQuoteAsset[0] = true;
        bytes32 oracleSequence = BitPackingLib.pack(baseToQuoteAsset, oraclesIds);

        uint256 actualRate = registry.getRateInUsd(oracleSequence);
        assertEq(actualRate, expectedRate);
    }

    function testFuzz_Success_getRateInUsd_QuoteAssetToBaseAsset(uint80 oracleId, uint256 rate) public {
        rate = bound(rate, 1, type(uint256).max);

        addMockedOracle(oracleId, rate, bytes16("A"), bytes16("USD"), true);

        uint256 expectedRate = 1e36 / rate;

        uint80[] memory oraclesIds = new uint80[](1);
        oraclesIds[0] = oracleId;
        bool[] memory baseToQuoteAsset = new bool[](1);
        baseToQuoteAsset[0] = false;
        bytes32 oracleSequence = BitPackingLib.pack(baseToQuoteAsset, oraclesIds);

        uint256 actualRate = registry.getRateInUsd(oracleSequence);
        assertEq(actualRate, expectedRate);
    }
}
