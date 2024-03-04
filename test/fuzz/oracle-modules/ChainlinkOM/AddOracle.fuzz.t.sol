/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ChainlinkOM_Fuzz_Test } from "./_ChainlinkOM.fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/oracles/ArcadiaOracle.sol";
import { ChainlinkOM } from "../../../../src/oracle-modules/ChainlinkOM.sol";
import { OracleModule } from "../../../../src/oracle-modules/abstracts/AbstractOM.sol";

/**
 * @notice Fuzz tests for the function "addOracle" of contract "ChainlinkOM".
 */
contract AddOracle_ChainlinkOM_Fuzz_Test is ChainlinkOM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ChainlinkOM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addOracle_NonOwner(
        address unprivilegedAddress,
        address oracle,
        bytes16 baseAsset,
        bytes16 quoteAsset,
        uint32 cutOffTime
    ) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.prank(users.unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        chainlinkOM.addOracle(oracle, baseAsset, quoteAsset, cutOffTime);
    }

    function testFuzz_Revert_addOracle_OverwriteOracle(bytes16 baseAsset, bytes16 quoteAsset, uint32 cutOffTime)
        public
    {
        vm.startPrank(users.creatorAddress);
        chainlinkOM.addOracle(address(mockOracles.token4ToUsd), baseAsset, quoteAsset, cutOffTime);

        vm.expectRevert(OracleModule.OracleAlreadyAdded.selector);
        chainlinkOM.addOracle(address(mockOracles.token4ToUsd), baseAsset, quoteAsset, cutOffTime);
        vm.stopPrank();
    }

    function testFuzz_Revert_addOracle_NonOracle(
        address oracle,
        bytes16 baseAsset,
        bytes16 quoteAsset,
        uint32 cutOffTime
    ) public notTestContracts(oracle) {
        vm.prank(users.creatorAddress);
        vm.expectRevert(bytes(""));
        chainlinkOM.addOracle(oracle, baseAsset, quoteAsset, cutOffTime);
    }

    function testFuzz_Revert_addOracle_BigOracleUnit(
        bytes16 baseAsset,
        bytes16 quoteAsset,
        uint32 cutOffTime,
        uint8 decimals
    ) public {
        decimals = uint8(bound(decimals, 19, type(uint8).max));
        ArcadiaOracle oracle = new ArcadiaOracle(decimals, "STABLE1 / USD", address(0));

        vm.prank(users.creatorAddress);
        vm.expectRevert(ChainlinkOM.Max18Decimals.selector);
        chainlinkOM.addOracle(address(oracle), baseAsset, quoteAsset, cutOffTime);
    }

    function testFuzz_Success_addOracle(
        bytes16 baseAsset,
        bytes16 quoteAsset,
        uint32 cutOffTime,
        uint8 decimals,
        uint256 oracleCounterLast
    ) public {
        decimals = uint8(bound(decimals, 0, 18));
        ArcadiaOracle oracle = new ArcadiaOracle(decimals, "STABLE1 / USD", address(0));

        oracleCounterLast = bound(oracleCounterLast, 0, type(uint80).max);
        registryExtension.setOracleCounter(oracleCounterLast);

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(oracle), baseAsset, quoteAsset, cutOffTime);

        assertEq(oracleId, oracleCounterLast);

        assertTrue(chainlinkOM.getInOracleModule(address(oracle)));
        assertEq(chainlinkOM.oracleToOracleId(address(oracle)), oracleId);
        (uint256 cutOffTime_, uint64 unitCorrection, address oracle_) = chainlinkOM.getOracleInformation(oracleId);
        assertEq(cutOffTime_, cutOffTime);
        assertEq(unitCorrection, 10 ** (18 - decimals));
        assertEq(oracle_, address(oracle));
        (bytes16 baseAsset_, bytes16 quoteAsset_) = chainlinkOM.assetPair(oracleId);
        assertEq(baseAsset_, baseAsset);
        assertEq(quoteAsset_, quoteAsset);
        assertEq(registryExtension.getOracleToOracleModule(oracleId), address(chainlinkOM));
        assertEq(registryExtension.getOracleCounter(), oracleCounterLast + 1);
    }
}
