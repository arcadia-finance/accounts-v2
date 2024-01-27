/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Registry_Fuzz_Test, RegistryErrors } from "./_Registry.fuzz.t.sol";

import { BitPackingLib } from "../../../src/libraries/BitPackingLib.sol";
import { OracleModuleMock } from "../../utils/mocks/oracle-modules/OracleModuleMock.sol";

/**
 * @notice Fuzz tests for the function "checkOracleSequence" of contract "Registry".
 */
contract CheckOracleSequence_Registry_Fuzz_Test is Registry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Registry_Fuzz_Test.setUp();

        oracleModule = new OracleModuleMock(address(registryExtension));
    }

    /*//////////////////////////////////////////////////////////////
                         HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getOracleSequence(uint256 length, bool[3] memory baseToQuoteAsset, uint80[3] memory oracles)
        public
        pure
        returns (bytes32 oracleSequence)
    {
        bool[] memory directions_ = new bool[](length);
        uint80[] memory oracles_ = new uint80[](length);
        for (uint256 i; i < length; ++i) {
            directions_[i] = baseToQuoteAsset[i];
            oracles_[i] = oracles[i];

            // Oracles must be unique.
            for (uint256 j; j < i; ++j) {
                vm.assume(oracles_[i] != oracles_[j]);
            }
        }

        oracleSequence = BitPackingLib.pack(directions_, oracles_);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_checkOracleSequence_ZeroOracles(bytes32 oracleSequence) public {
        // Given length of oracles is zero (two rightmost bits are zero)
        oracleSequence = oracleSequence << 2;

        vm.expectRevert(RegistryErrors.Min1Oracle.selector);
        registryExtension.checkOracleSequence(oracleSequence);
    }

    function testFuzz_Revert_checkOracleSequence_UnknownOracle(bool direction, uint80 oracleId) public {
        // Given: An oracle not added to the "Registry".
        oracleId = uint80(bound(oracleId, registryExtension.getOracleCounter(), type(uint80).max));

        uint80[] memory oraclesIds = new uint80[](1);
        oraclesIds[0] = oracleId;
        bool[] memory baseToQuoteAsset = new bool[](1);
        baseToQuoteAsset[0] = direction;

        bytes32 oracleSequence = BitPackingLib.pack(baseToQuoteAsset, oraclesIds);

        vm.expectRevert(bytes(""));
        registryExtension.checkOracleSequence(oracleSequence);
    }

    function testFuzz_Success_checkOracleSequence_Negative_InactiveOracle(
        uint256 length,
        bool[3] memory baseToQuoteAsset,
        uint80[3] memory oracles
    ) public {
        length = bound(length, 1, 3);
        bytes32 oracleSequence = getOracleSequence(length, baseToQuoteAsset, oracles);

        bytes16 baseAsset;
        bytes16 quoteAsset;
        // Set first oracle to inactive
        if (length == 1) {
            (baseAsset, quoteAsset) =
                baseToQuoteAsset[0] ? (bytes16("A"), bytes16("USD")) : (bytes16("USD"), bytes16("A"));
            addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, false);
        } else {
            (baseAsset, quoteAsset) = baseToQuoteAsset[0] ? (bytes16("A"), bytes16("B")) : (bytes16("B"), bytes16("A"));
            addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, false);
            if (length == 2) {
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[1] ? (bytes16("B"), bytes16("USD")) : (bytes16("USD"), bytes16("B"));
                addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
            } else {
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[1] ? (bytes16("B"), bytes16("C")) : (bytes16("C"), bytes16("B"));
                addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[2] ? (bytes16("C"), bytes16("USD")) : (bytes16("USD"), bytes16("C"));
                addMockedOracle(oracles[2], 0, baseAsset, quoteAsset, true);
            }
        }

        bool success = registryExtension.checkOracleSequence(oracleSequence);

        assertFalse(success);
    }

    function testFuzz_Success_checkOracleSequence_Negative_NonMatchingConsecutiveAssets(
        uint256 length,
        bool[3] memory baseToQuoteAsset,
        uint80[3] memory oracles
    ) public {
        length = bound(length, 2, 3);
        bytes32 oracleSequence = getOracleSequence(length, baseToQuoteAsset, oracles);

        (bytes16 baseAsset, bytes16 quoteAsset) =
            baseToQuoteAsset[0] ? (bytes16("A"), bytes16("B")) : (bytes16("B"), bytes16("A"));
        addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, true);
        if (length == 2) {
            (baseAsset, quoteAsset) =
                baseToQuoteAsset[1] ? (bytes16("NOT_B"), bytes16("USD")) : (bytes16("USD"), bytes16("NOT_B"));
            addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
        } else {
            (baseAsset, quoteAsset) =
                baseToQuoteAsset[1] ? (bytes16("NOT_B"), bytes16("C")) : (bytes16("C"), bytes16("NOT_B"));
            addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
            (baseAsset, quoteAsset) =
                baseToQuoteAsset[2] ? (bytes16("C"), bytes16("USD")) : (bytes16("USD"), bytes16("C"));
            addMockedOracle(oracles[2], 0, baseAsset, quoteAsset, true);
        }

        bool success = registryExtension.checkOracleSequence(oracleSequence);

        assertFalse(success);
    }

    function testFuzz_Success_checkOracleSequence_Negative_LastBaseAssetNotUsd(
        uint256 length,
        bool[3] memory baseToQuoteAsset,
        uint80[3] memory oracles
    ) public {
        length = bound(length, 1, 3);
        bytes32 oracleSequence = getOracleSequence(length, baseToQuoteAsset, oracles);

        bytes16 baseAsset;
        bytes16 quoteAsset;
        if (length == 1) {
            (baseAsset, quoteAsset) =
                baseToQuoteAsset[0] ? (bytes16("A"), bytes16("NOT_USD")) : (bytes16("NOT_USD"), bytes16("A"));
            addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, true);
        } else {
            (baseAsset, quoteAsset) = baseToQuoteAsset[0] ? (bytes16("A"), bytes16("B")) : (bytes16("B"), bytes16("A"));
            addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, true);
            if (length == 2) {
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[1] ? (bytes16("B"), bytes16("NOT_USD")) : (bytes16("NOT_USD"), bytes16("B"));
                addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
            } else {
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[1] ? (bytes16("B"), bytes16("C")) : (bytes16("C"), bytes16("B"));
                addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[2] ? (bytes16("C"), bytes16("NOT_USD")) : (bytes16("NOT_USD"), bytes16("C"));
                addMockedOracle(oracles[2], 0, baseAsset, quoteAsset, true);
            }
        }

        bool success = registryExtension.checkOracleSequence(oracleSequence);

        assertFalse(success);
    }

    function testFuzz_Success_checkOracleSequence(
        uint256 length,
        bool[3] memory baseToQuoteAsset,
        uint80[3] memory oracles
    ) public {
        length = bound(length, 1, 3);
        bytes32 oracleSequence = getOracleSequence(length, baseToQuoteAsset, oracles);

        bytes16 baseAsset;
        bytes16 quoteAsset;
        if (length == 1) {
            (baseAsset, quoteAsset) =
                baseToQuoteAsset[0] ? (bytes16("A"), bytes16("USD")) : (bytes16("USD"), bytes16("A"));
            addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, true);
        } else {
            (baseAsset, quoteAsset) = baseToQuoteAsset[0] ? (bytes16("A"), bytes16("B")) : (bytes16("B"), bytes16("A"));
            addMockedOracle(oracles[0], 0, baseAsset, quoteAsset, true);
            if (length == 2) {
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[1] ? (bytes16("B"), bytes16("USD")) : (bytes16("USD"), bytes16("B"));
                addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
            } else {
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[1] ? (bytes16("B"), bytes16("C")) : (bytes16("C"), bytes16("B"));
                addMockedOracle(oracles[1], 0, baseAsset, quoteAsset, true);
                (baseAsset, quoteAsset) =
                    baseToQuoteAsset[2] ? (bytes16("C"), bytes16("USD")) : (bytes16("USD"), bytes16("C"));
                addMockedOracle(oracles[2], 0, baseAsset, quoteAsset, true);
            }
        }

        bool success = registryExtension.checkOracleSequence(oracleSequence);

        assertTrue(success);
    }
}
