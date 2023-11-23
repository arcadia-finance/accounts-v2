/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ChainlinkOracleModule_Fuzz_Test } from "./_ChainlinkOracleModule.fuzz.t.sol";

import { ArcadiaOracle } from "../../../utils/mocks/ArcadiaOracle.sol";
import { ChainlinkOracleModule } from "../../../../src/oracle-modules/ChainlinkOracleModule.sol";
import { OracleModule } from "../../../../src/oracle-modules/AbstractOracleModule.sol";

/**
 * @notice Fuzz tests for the function "addOracle" of contract "ChainlinkOracleModule".
 */
contract AddOracle_ChainlinkOracleModule_Fuzz_Test is ChainlinkOracleModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        ChainlinkOracleModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addOracle_NonOwner(
        address unprivilegedAddress,
        address oracle,
        bytes16 baseAsset,
        bytes16 quoteAsset
    ) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.prank(users.unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        chainlinkOM.addOracle(oracle, baseAsset, quoteAsset);
    }

    function testFuzz_Revert_addOracle_OverwriteOracle(bytes16 baseAsset, bytes16 quoteAsset) public {
        vm.startPrank(users.creatorAddress);
        chainlinkOM.addOracle(address(mockOracles.token4ToUsd), baseAsset, quoteAsset);

        vm.expectRevert(OracleModule.OracleAlreadyAdded.selector);
        chainlinkOM.addOracle(address(mockOracles.token4ToUsd), baseAsset, quoteAsset);
        vm.stopPrank();
    }

    function testFuzz_Revert_addOracle_NonOracle(address oracle, bytes16 baseAsset, bytes16 quoteAsset) public {
        vm.assume(oracle != address(mockOracles.token1ToUsd));
        vm.assume(oracle != address(mockOracles.token2ToUsd));
        vm.assume(oracle != address(mockOracles.token3ToToken4));
        vm.assume(oracle != address(mockOracles.token4ToUsd));
        vm.assume(oracle != address(mockOracles.stable1ToUsd));
        vm.assume(oracle != address(mockOracles.stable2ToUsd));
        vm.assume(oracle != address(mockOracles.nft1ToToken1));
        vm.assume(oracle != address(mockOracles.nft2ToUsd));
        vm.assume(oracle != address(mockOracles.nft3ToToken1));
        vm.assume(oracle != address(mockOracles.sft1ToToken1));
        vm.assume(oracle != address(mockOracles.sft2ToUsd));
        vm.assume(oracle != address(mockERC20.stable1));
        vm.assume(oracle != address(mockERC20.stable2));
        vm.assume(oracle != address(mockERC20.token1));
        vm.assume(oracle != address(mockERC20.token2));
        vm.assume(oracle != address(mockERC20.token3));
        vm.assume(oracle != address(mockERC20.token4));
        vm.assume(oracle != address(vm));

        vm.prank(users.creatorAddress);
        vm.expectRevert(bytes(""));
        chainlinkOM.addOracle(oracle, baseAsset, quoteAsset);
    }

    function testFuzz_Revert_addOracle_BigOracleUnit(bytes16 baseAsset, bytes16 quoteAsset, uint8 decimals) public {
        decimals = uint8(bound(decimals, 19, type(uint8).max));
        ArcadiaOracle oracle = new ArcadiaOracle(decimals, "STABLE1 / USD", address(0));

        vm.prank(users.creatorAddress);
        vm.expectRevert(ChainlinkOracleModule.Max18Decimals.selector);
        chainlinkOM.addOracle(address(oracle), baseAsset, quoteAsset);
    }

    function testFuzz_Success_addOracle(
        bytes16 baseAsset,
        bytes16 quoteAsset,
        uint8 decimals,
        uint256 oracleCounterLast
    ) public {
        decimals = uint8(bound(decimals, 0, 18));
        ArcadiaOracle oracle = new ArcadiaOracle(decimals, "STABLE1 / USD", address(0));

        oracleCounterLast = bound(oracleCounterLast, 0, type(uint80).max);
        registryExtension.setOracleCounter(oracleCounterLast);

        vm.prank(users.creatorAddress);
        uint256 oracleId = chainlinkOM.addOracle(address(oracle), baseAsset, quoteAsset);

        assertEq(oracleId, oracleCounterLast);

        assertTrue(chainlinkOM.getInOracleModule(address(oracle)));
        assertEq(chainlinkOM.oracleToOracleId(address(oracle)), oracleId);
        (bool isActive, uint64 unitCorrection, address oracle_) = chainlinkOM.getOracleInformation(oracleId);
        assertEq(isActive, true);
        assertEq(unitCorrection, 10 ** (18 - decimals));
        assertEq(oracle_, address(oracle));
        (bytes16 baseAsset_, bytes16 quoteAsset_) = chainlinkOM.assetPair(oracleId);
        assertEq(baseAsset_, baseAsset);
        assertEq(quoteAsset_, quoteAsset);
        assertEq(registryExtension.getOracleToOracleModule(oracleId), address(chainlinkOM));
        assertEq(registryExtension.getOracleCounter(), oracleCounterLast + 1);
    }
}
