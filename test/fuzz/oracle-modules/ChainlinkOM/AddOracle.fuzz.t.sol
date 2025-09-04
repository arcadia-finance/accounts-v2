/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

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
        vm.assume(unprivilegedAddress != users.owner);

        vm.prank(users.unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        chainlinkOM.addOracle(oracle, baseAsset, quoteAsset, cutOffTime);
    }

    function testFuzz_Revert_addOracle_OverwriteOracle(bytes16 baseAsset, bytes16 quoteAsset, uint32 cutOffTime)
        public
    {
        vm.startPrank(users.owner);
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
    ) public canReceiveERC721(oracle) {
        vm.assume(oracle != address(account));
        vm.assume(oracle != address(accountLogic));
        vm.assume(!isPrecompile(oracle));

        vm.prank(users.owner);
        if (oracle.code.length == 0 && !isPrecompile(oracle)) {
            vm.expectRevert(abi.encodePacked("call to non-contract address ", vm.toString(oracle)));
        } else {
            vm.expectRevert(bytes(""));
        }
        chainlinkOM.addOracle(oracle, baseAsset, quoteAsset, cutOffTime);
    }

    function testFuzz_Revert_addOracle_BigOracleUnit(
        bytes16 baseAsset,
        bytes16 quoteAsset,
        uint32 cutOffTime,
        uint8 decimals
    ) public {
        decimals = uint8(bound(decimals, 19, type(uint8).max));
        ArcadiaOracle oracle = new ArcadiaOracle(decimals, "STABLE1 / USD");

        vm.prank(users.owner);
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
        ArcadiaOracle oracle = new ArcadiaOracle(decimals, "STABLE1 / USD");

        oracleCounterLast = bound(oracleCounterLast, 0, type(uint80).max);
        registry.setOracleCounter(oracleCounterLast);

        vm.prank(users.owner);
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
        assertEq(registry.getOracleToOracleModule(oracleId), address(chainlinkOM));
        assertEq(registry.getOracleCounter(), oracleCounterLast + 1);
    }
}
