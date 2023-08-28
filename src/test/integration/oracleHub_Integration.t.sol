/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { OracleHub_UsdOnly } from "../../OracleHub_UsdOnly.sol";

contract RevertingOracle {
    function latestRoundData() public pure returns (uint80, int256, uint256, uint256, uint80) {
        revert();
    }
}

contract OracleHub_Integration_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testRevert_checkOracleSequence_InactiveOracle() public {
        vm.prank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(Constants.tokenOracleDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );

        vm.prank(users.defaultTransmitter);
        mockOracles.token4ToUsd.transmit(0); // Lower than min value

        oracleHub.decommissionOracle(address(mockOracles.token4ToUsd));

        address[] memory oracleToken4ToUsdArr = new address[](1);
        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);

        // Then: checkOracleSequence with oracleToken4ToUsdArr should revert with "OH_COS: Oracle not active"
        vm.expectRevert("OH_COS: Oracle not active");
        oracleHub.checkOracleSequence(oracleToken4ToUsdArr, address(mockERC20.token4));
    }

    function testRevert_Fuzz_decommissionOracle_notInHub(address sender, address oracle) public {
        vm.assume(oracle != address(mockOracles.token1ToUsd));
        vm.assume(oracle != address(mockOracles.token2ToUsd));
        vm.assume(oracle != address(mockOracles.stable1ToUsd));
        vm.assume(oracle != address(mockOracles.stable2ToUsd));

        vm.startPrank(sender);
        vm.expectRevert("OH_DO: Oracle not in Hub");
        oracleHub.decommissionOracle(oracle);
        vm.stopPrank();
    }

    function testFuzz_decommissionOracle_NonExistingContract(address sender) public {
        RevertingOracle revertingOracle = new RevertingOracle();

        vm.prank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
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

    function testFuzz_decommissionOracle_answerTooLow(address sender) public {
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
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

    function testFuzz_decommissionOracle_updatedAtTooOld(address sender, uint32 timePassed) public {
        vm.assume(timePassed > 1 weeks);

        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
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

    function testFuzz_decommissionOracle_resetOracleInUse(address sender, uint32 timePassed) public {
        vm.assume(timePassed > 1 weeks);

        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** Constants.tokenOracleDecimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
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

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testRevert_Fuzz_getRateInUsd_NegativeRate(int256 rateToken1ToUsd) public {
        // Given: oracleToken1ToUsdDecimals less than equal to 18, rateToken1ToUsd less than equal to max uint256 value,
        // rateToken1ToUsd is less than max uint256 value divided by WAD
        vm.assume(rateToken1ToUsd < 0);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);
        vm.stopPrank();

        vm.expectRevert("OH_GR: Negative Rate");
        oracleHub.getRateInUsd(oracleToken1ToUsdArr);
    }

    function testFuzz_getRateInUsd_SingleOracle(uint256 rateToken4ToUsd, uint8 oracleToken4ToUsdDecimals) public {
        // Given: oracleToken4ToUsdDecimals less than equal to 18, rateToken1ToUsd less than equal to max uint256 value,
        // rateToken1ToUsd is less than max uint256 value divided by WAD
        vm.assume(oracleToken4ToUsdDecimals <= 18);
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken4ToUsd <= type(uint256).max / Constants.WAD);

        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken4ToUsdDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token4ToUsd.transmit(int256(rateToken4ToUsd));
        vm.stopPrank();

        address[] memory oracleToken4ToUsdArr = new address[](1);
        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);

        uint256 expectedRateInUsd = (Constants.WAD * uint256(rateToken4ToUsd)) / 10 ** (oracleToken4ToUsdDecimals);
        uint256 actualRateInUsd = oracleHub.getRateInUsd(oracleToken4ToUsdArr);

        // Then: actualRateInUsd should be equal to expectedRateInUsd
        assertEq(actualRateInUsd, expectedRateInUsd);
    }

    function testRevert_Fuzz_getRateInUsd_SingleOracleOverflow(uint256 rateToken4ToUsd, uint8 oracleToken4ToUsdDecimals)
        public
    {
        // Given: oracleToken4ToUsdDecimals less than equal to 18, rateToken4ToUsd less than equal to max uint256 value,
        // rateToken4ToUsd is more than max uint256 value divided by WAD
        vm.assume(oracleToken4ToUsdDecimals <= 18);
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken4ToUsd > type(uint256).max / Constants.WAD);

        vm.startPrank(users.creatorAddress);
        // When: creatorAddress addOracle with OracleInformation for TOKEN4-USD, oracleOwner transmit rateToken4ToUsd,
        // oraclesToken4ToUsd index 0 is oracleToken4ToUsd, oracleOwner getRate
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken4ToUsdDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token4ToUsd.transmit(int256(rateToken4ToUsd));
        vm.stopPrank();

        address[] memory oracleToken4ToUsdArr = new address[](1);
        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);

        // Then: getRateInUsd should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRateInUsd(oracleToken4ToUsdArr);
    }

    function testFuzz_getRateInUsd_MultipleOracles(
        uint256 rateToken3ToToken4,
        uint256 rateToken4ToUsd,
        uint8 oracleToken3ToToken4Decimals,
        uint8 oracleToken4ToUsdDecimals
    ) public {
        // Given: oracleToken3ToToken4Decimals and oracleToken4ToUsdDecimals is less than equal to 18,
        // rateToken3ToToken4 and rateToken4ToUsd is less than equal to uint256 max value, rateToken3ToToken4 is less than equal to uint256 max value divided by WAD
        vm.assume(oracleToken3ToToken4Decimals <= 18 && oracleToken4ToUsdDecimals <= 18);

        vm.assume(rateToken3ToToken4 <= uint256(type(int256).max));
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));

        vm.assume(rateToken3ToToken4 <= type(uint256).max / Constants.WAD);

        if (rateToken3ToToken4 == 0) {
            vm.assume(uint256(rateToken4ToUsd) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(rateToken4ToUsd)
                    <= type(uint256).max / Constants.WAD * 10 ** oracleToken3ToToken4Decimals / uint256(rateToken3ToToken4)
            );
        }

        // When: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD, oracleOwner transmit rateToken3ToToken4 and rateToken4ToUsd,
        // oraclesToken3ToUsd index 0 is oracleToken3ToToken4, oraclesToken3ToUsd index 1 is oracleToken4ToUsd
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken3ToToken4Decimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken4ToUsdDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(int256(rateToken3ToToken4));
        mockOracles.token4ToUsd.transmit(int256(rateToken4ToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (
            ((Constants.WAD * uint256(rateToken3ToToken4)) / 10 ** (oracleToken3ToToken4Decimals))
                * uint256(rateToken4ToUsd)
        ) / 10 ** (oracleToken4ToUsdDecimals);

        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        oracleToken3ToUsdArr[1] = address(mockOracles.token4ToUsd);
        uint256 actualRateInUsd = oracleHub.getRateInUsd(oracleToken3ToUsdArr);

        // Then: expectedRateInUsd should be equal to actualRateInUsd
        assertEq(expectedRateInUsd, actualRateInUsd);
    }

    function testFuzz_getRateInUsd_MultipleOracles_Overflow1(
        uint256 rateToken3ToToken4,
        uint256 rateToken4ToUsd,
        uint8 oracleToken3ToToken4Decimals,
        uint8 oracleToken4ToUsdDecimals
    ) public {
        // Given: oracleToken3ToToken4Decimals and oracleToken4ToUsdDecimals is less than equal to 18,
        // rateToken3ToToken4 and rateToken4ToUsd is less than equal to uint256 max value, rateToken3ToToken4 is bigger than uint256 max value divided by WAD
        vm.assume(oracleToken3ToToken4Decimals <= 18 && oracleToken4ToUsdDecimals <= 18);
        vm.assume(rateToken3ToToken4 <= uint256(type(int256).max));
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));

        vm.assume(rateToken3ToToken4 > type(uint256).max / Constants.WAD);

        if (rateToken3ToToken4 == 0) {
            vm.assume(uint256(rateToken4ToUsd) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(rateToken4ToUsd)
                    <= type(uint256).max / Constants.WAD * 10 ** oracleToken3ToToken4Decimals / uint256(rateToken3ToToken4)
            );
        }

        // When: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD, oracleOwner transmit rateToken3ToToken4 and rateToken4ToUsd,
        // oraclesToken3ToUsd index 0 is oracleToken3ToToken4, oraclesToken3ToUsd index 1 is oracleToken4ToUsd
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken3ToToken4Decimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken4ToUsdDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(int256(rateToken3ToToken4));
        mockOracles.token4ToUsd.transmit(int256(rateToken4ToUsd));
        vm.stopPrank();

        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        oracleToken3ToUsdArr[1] = address(mockOracles.token4ToUsd);

        // Then: getRateInUsd() should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRateInUsd(oracleToken3ToUsdArr);
    }

    function testFuzz_getRateInUsd_MultipleOracles_Overflow2(
        uint256 rateToken3ToToken4,
        uint256 rateToken4ToUsd,
        uint8 oracleToken3ToToken4Decimals,
        uint8 oracleToken4ToUsdDecimals
    ) public {
        // Given: oracleToken3ToToken4Decimals and oracleToken4ToUsdDecimals is less than equal to 18,
        // rateToken3ToToken4 and rateToken4ToUsd is less than equal to uint256 max value, rateToken3ToToken4 is bigger than 0.
        vm.assume(oracleToken3ToToken4Decimals <= 18 && oracleToken4ToUsdDecimals <= 18);
        vm.assume(rateToken3ToToken4 <= uint256(type(int256).max));
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken3ToToken4 > 0);

        vm.assume(
            uint256(rateToken4ToUsd)
                > type(uint256).max / Constants.WAD * 10 ** oracleToken3ToToken4Decimals / uint256(rateToken3ToToken4)
        );

        // When: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD, oracleOwner transmit rateToken3ToToken4 and rateToken4ToUsd,
        // oraclesToken3ToUsd index 0 is oracleToken3ToToken4, oraclesToken3ToUsd index 1 is oracleToken4ToUsd
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken3ToToken4Decimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken4ToUsdDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(int256(rateToken3ToToken4));
        mockOracles.token4ToUsd.transmit(int256(rateToken4ToUsd));
        vm.stopPrank();

        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        oracleToken3ToUsdArr[1] = address(mockOracles.token4ToUsd);

        // Then: getRateInUsd() should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRateInUsd(oracleToken3ToUsdArr);
    }

    function testFuzz_getRateInUsd_MultipleOracles_FirstRateIsZero(
        uint256 rateToken4ToUsd,
        uint8 oracleToken3ToToken4Decimals,
        uint8 oracleToken4ToUsdDecimals
    ) public {
        // Given: oracleToken3ToToken4Decimals and oracleToken4ToUsdDecimals is less than equal to 18,
        // rateToken4ToUsd is less than equal to uint256 max value, rateToken3ToToken4 is 0
        uint256 rateToken3ToToken4 = 0;

        vm.assume(oracleToken3ToToken4Decimals <= 18 && oracleToken4ToUsdDecimals <= 18);
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));

        // When: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD, oracleOwner transmit rateToken3ToToken4 and rateToken4ToUsd,
        // oraclesToken3ToUsd index 0 is oracleToken3ToToken4, oraclesToken3ToUsd index 1 is oracleToken4ToUsd
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken3ToToken4Decimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken4ToUsdDecimals),
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token3ToToken4.transmit(int256(rateToken3ToToken4));
        mockOracles.token4ToUsd.transmit(int256(rateToken4ToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (
            ((Constants.WAD * uint256(rateToken3ToToken4)) / 10 ** (oracleToken3ToToken4Decimals))
                * uint256(rateToken4ToUsd)
        ) / 10 ** (oracleToken4ToUsdDecimals);

        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        oracleToken3ToUsdArr[1] = address(mockOracles.token4ToUsd);

        uint256 actualRateInUsd = oracleHub.getRateInUsd(oracleToken3ToUsdArr);

        // Then: expectedRateInUsd should be equal to actualRateInUsd
        assertEq(expectedRateInUsd, actualRateInUsd);
    }
}
