/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, OracleHub_Fuzz_Test } from "./OracleHub.fuzz.t.sol";

import { OracleHub } from "../../../OracleHub.sol";
import { RevertingOracle } from "../../mocks/RevertingOracle.sol";

/**
 * @notice Fuzz tests for the function "decommissionOracle" of contract "OracleHub".
 */
contract DecommissionOracle_OracleHub_Fuzz_Test is OracleHub_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        OracleHub_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_Fuzz_decommissionOracle_notInHub(address sender, address oracle) public {
        vm.assume(oracle != address(mockOracles.token1ToUsd));
        vm.assume(oracle != address(mockOracles.token2ToUsd));
        vm.assume(oracle != address(mockOracles.stable1ToUsd));
        vm.assume(oracle != address(mockOracles.stable2ToUsd));
        vm.assume(oracle != address(mockOracles.nft1ToToken1));
        vm.assume(oracle != address(mockOracles.sft1ToToken1));

        vm.startPrank(sender);
        vm.expectRevert("OH_DO: Oracle not in Hub");
        oracleHub.decommissionOracle(oracle);
        vm.stopPrank();
    }

    function testFuzz_decommissionOracle_RevertingOracle(address sender) public {
        RevertingOracle revertingOracle = new RevertingOracle();

        vm.prank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: 10 ** 18,
                baseAsset: "REVERT",
                quoteAsset: "USD",
                oracle: address(revertingOracle),
                baseAssetAddress: address(0),
                isActive: true
            })
        );

        vm.startPrank(sender);
        vm.expectEmit();
        emit OracleDecommissioned(address(revertingOracle), false);
        oracleHub.decommissionOracle(address(revertingOracle));
        vm.stopPrank();

        (bool isActive,,,,,) = oracleHub.oracleToOracleInformation(address(revertingOracle));
        assertEq(isActive, false);

        address[] memory oracles = new address[](1);
        oracles[0] = address(revertingOracle);

        uint256 rate = oracleHub.getRateInUsd(oracles);

        assertEq(rate, 0);
    }

    function testFuzz_Pass_decommissionOracle_answerTooLow(address sender) public {
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        vm.stopPrank();

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(users.defaultTransmitter);
        //minAnswer is set to 100 in the oracle mocks
        mockOracles.token3ToToken4.transmit(int256(1));
        mockOracles.token4ToUsd.transmit(int256(500_000_000_000));
        vm.stopPrank();

        (bool isActive,,,,,) = oracleHub.oracleToOracleInformation(address(mockOracles.token3ToToken4));
        assertEq(isActive, true);

        vm.startPrank(sender);
        vm.expectEmit();
        emit OracleDecommissioned(address(mockOracles.token3ToToken4), false);
        oracleHub.decommissionOracle(address(mockOracles.token3ToToken4));
        vm.stopPrank();

        (isActive,,,,,) = oracleHub.oracleToOracleInformation(address(mockOracles.token3ToToken4));
        assertEq(isActive, false);

        address[] memory oracles = new address[](2);
        oracles[0] = address(mockOracles.token3ToToken4);
        oracles[1] = address(mockOracles.token4ToUsd);

        uint256 rate = oracleHub.getRateInUsd(oracles);

        assertEq(rate, 0);
    }

    function testFuzz_Pass_decommissionOracle_updatedAtTooOld(address sender, uint32 timePassed) public {
        vm.assume(timePassed > 1 weeks);

        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        vm.stopPrank();

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(users.defaultTransmitter);
        //minAnswer is set to 100 in the oracle mocks
        mockOracles.token3ToToken4.transmit(int256(500_000_000_000));
        mockOracles.token4ToUsd.transmit(int256(500_000_000_000));
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);

        (bool isActive,,,,,) = oracleHub.oracleToOracleInformation(address(mockOracles.token3ToToken4));
        assertEq(isActive, true);

        vm.startPrank(sender);
        vm.expectEmit();
        emit OracleDecommissioned(address(mockOracles.token3ToToken4), false);
        oracleHub.decommissionOracle(address(mockOracles.token3ToToken4));
        vm.stopPrank();

        (isActive,,,,,) = oracleHub.oracleToOracleInformation(address(mockOracles.token3ToToken4));
        assertEq(isActive, false);

        address[] memory oracles = new address[](2);
        oracles[0] = address(mockOracles.token3ToToken4);
        oracles[1] = address(mockOracles.token4ToUsd);

        uint256 rate = oracleHub.getRateInUsd(oracles);

        assertEq(rate, 0);
    }

    function testFuzz_Pass_decommissionOracle_ReactivateOracle(address sender, uint32 timePassed) public {
        vm.assume(timePassed > 1 weeks);

        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        vm.warp(2 weeks); //to not run into an underflow

        vm.startPrank(users.defaultTransmitter);
        //minAnswer is set to 100 in the oracle mocks
        mockOracles.token3ToToken4.transmit(int256(50_000));
        mockOracles.token4ToUsd.transmit(int256(50_000)); //only one of the two is needed to fail
        vm.stopPrank();

        vm.warp(block.timestamp + timePassed);

        (bool isActive,,,,,) = oracleHub.oracleToOracleInformation(address(mockOracles.token3ToToken4));
        assertEq(isActive, true);

        vm.startPrank(sender);
        vm.expectEmit();
        emit OracleDecommissioned(address(mockOracles.token3ToToken4), false);
        oracleHub.decommissionOracle(address(mockOracles.token3ToToken4));
        vm.stopPrank();

        (isActive,,,,,) = oracleHub.oracleToOracleInformation(address(mockOracles.token3ToToken4));
        assertEq(isActive, false);

        address[] memory oracles = new address[](2);
        oracles[0] = address(mockOracles.token3ToToken4);
        oracles[1] = address(mockOracles.token4ToUsd);

        uint256 rate = oracleHub.getRateInUsd(oracles);

        assertEq(rate, 0);

        // Given: Oracle is operating again.
        vm.startPrank(users.defaultTransmitter);
        //minAnswer is set to 100 in the oracle mocks
        mockOracles.token3ToToken4.transmit(int256(50_000));
        mockOracles.token4ToUsd.transmit(int256(50_000));
        vm.stopPrank();

        vm.startPrank(sender);
        vm.expectEmit();
        emit OracleDecommissioned(address(mockOracles.token3ToToken4), true);
        oracleHub.decommissionOracle(address(mockOracles.token3ToToken4));
        vm.stopPrank();

        (isActive,,,,,) = oracleHub.oracleToOracleInformation(address(mockOracles.token3ToToken4));
        assertEq(isActive, true);

        rate = oracleHub.getRateInUsd(oracles);

        assertGt(rate, 0);
    }
}
