/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Fuzz_Test, Constants } from "./Fuzz.t.sol";
import { OracleHub_UsdOnly } from "../../OracleHub_UsdOnly.sol";

contract RevertingOracle {
    function latestRoundData() public pure returns (uint80, int256, uint256, uint256, uint80) {
        revert();
    }
}

contract OracleHub_Fuzz_Test is Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                          ORACLE MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_addOracle_Owner(uint64 oracleToken4ToUsdUnit) public {
        // Given: oracleToken4ToUsdUnit is less than equal to 1 ether
        vm.assume(oracleToken4ToUsdUnit <= 10 ** 18);
        // When: creatorAddress addOracle with OracleInformation
        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        emit OracleAdded(address(mockOracles.token4ToUsd), address(mockERC20.token4), "USD");
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: oracleToken4ToUsdUnit,
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();

        // Then: oracleToken4ToUsd should return true to inOracleHub
        assertTrue(oracleHub.inOracleHub(address(mockOracles.token4ToUsd)));
        (bool isActive, uint64 oracleUnit,, address baseAssetAddress, bytes16 baseAsset, bytes16 quoteAsset) =
            oracleHub.oracleToOracleInformation(address(mockOracles.token4ToUsd));
        assertEq(oracleUnit, oracleToken4ToUsdUnit);
        assertEq(baseAsset, "TOKEN4");
        assertEq(quoteAsset, "USD");
        assertEq(baseAssetAddress, address(mockERC20.token4));
        assertEq(isActive, true);
    }

    function testRevert_addOracle_OverwriteOracle() public {
        vm.startPrank(users.creatorAddress);
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
        // When: creatorAddress addOracle

        // Then: addOracle should revert with "OH_AO: Oracle not unique"
        vm.expectRevert("OH_AO: Oracle not unique");
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
        vm.stopPrank();
    }

    function testRevert_Fuzz_addOracle_NonOwner(address unprivilegedAddress) public {
        // Given: unprivilegedAddress is not creatorAddress
        vm.assume(unprivilegedAddress != users.creatorAddress);
        // When: unprivilegedAddress addOracle
        vm.startPrank(users.unprivilegedAddress);
        // Then: addOracle should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
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
        vm.stopPrank();
    }

    function testRevert_Fuzz_addOracle_BigOracleUnit(uint64 oracleEthToUsdUnit) public {
        // Given: oracleEthToUsdUnit is bigger than 1 ether
        vm.assume(oracleEthToUsdUnit > 10 ** 18);
        // When: creatorAddress addOracle
        vm.startPrank(users.creatorAddress);
        // Then: addOracle should revert with "OH_AO: Maximal 18 decimals"
        vm.expectRevert("OH_AO: Maximal 18 decimals");
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: oracleEthToUsdUnit,
                baseAsset: "TOKEN4",
                quoteAsset: "USD",
                oracle: address(mockOracles.token4ToUsd),
                baseAssetAddress: address(mockERC20.token4),
                isActive: true
            })
        );
        vm.stopPrank();
    }

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

    function test_checkOracleSequence_SingleOracleToUsd() public {
        vm.startPrank(users.creatorAddress);
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
        vm.stopPrank();
        // When: oracleToken4ToUsdArr index 0 is mockOracles.token4ToUsd
        address[] memory oracleToken4ToUsdArr = new address[](1);
        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);
        // Then: checkOracleSequence should pass for oracleToken4ToUsdArr
        oracleHub.checkOracleSequence(oracleToken4ToUsdArr, address(mockERC20.token4));
    }

    function test_checkOracleSequence_MultipleOraclesToUsd() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD
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
        vm.stopPrank();
        // When: oracleToken3ToUsdArr index 0 is oracleToken3ToToken4, oracleToken3ToUsdArr index 1 is oracleToken4ToUsd,

        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        oracleToken3ToUsdArr[1] = address(mockOracles.token4ToUsd);
        // Then: checkOracleSequence should past for oracleToken3ToUsdArr
        oracleHub.checkOracleSequence(oracleToken3ToUsdArr, address(mockERC20.token3));
    }

    function testRevert_Fuzz_checkOracleSequence_NonMatchingFirstQuoteAssets(address asset) public {
        vm.assume(asset != address(mockERC20.token4));
        vm.startPrank(users.creatorAddress);
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
        vm.stopPrank();

        // When: oracleToken4ToUsdArr index 0 is mockOracles.token4ToUsd
        address[] memory oracleToken4ToUsdArr = new address[](1);
        oracleToken4ToUsdArr[0] = address(mockOracles.token4ToUsd);

        // Then: checkOracleSequence with oracleToken4ToUsdArr should revert with "OH_COS: No Match First bAsset" as asset != address(mockERC20.token4)
        vm.expectRevert("OH_COS: No Match First bAsset");
        oracleHub.checkOracleSequence(oracleToken4ToUsdArr, asset);
    }

    function testRevert_checkOracleSequence_NonMatchingBaseAndQuoteAssets() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for TOKEN3-TOKEN4
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
        // When: oracleToken3ToUsdArr index 0 is mockOracles.token3ToToken4, oracleToken3ToUsdArr index 1 is mockOracles.token1ToUsd
        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        oracleToken3ToUsdArr[1] = address(mockOracles.token1ToUsd);
        // Then: checkOracleSequence for oracleToken3ToUsdArr should revert with "OH_COS: No Match bAsset and qAsset"
        vm.expectRevert("OH_COS: No Match bAsset and qAsset");
        oracleHub.checkOracleSequence(oracleToken3ToUsdArr, address(mockERC20.token3));
    }

    function testRevert_checkOracleSequence_LastBaseAssetNotUsd() public {
        vm.startPrank(users.creatorAddress);
        // Given: creatorAddress addOracle with OracleInformation for TOKEN3-TOKEN4
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
        // When: racleToken3ToUsdArr index 0 is mockOracles.token3ToToken4
        address[] memory oracleToken3ToUsdArr = new address[](1);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken4);
        // Then: checkOracleSequence for oracleToken3ToUsdArr should revert with "OH_COS: Last qAsset not USD"
        vm.expectRevert("OH_COS: Last qAsset not USD");
        oracleHub.checkOracleSequence(oracleToken3ToUsdArr, address(mockERC20.token3));
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

    function test_isActive_negative(address oracle) public {
        vm.assume(oracle != address(mockOracles.token1ToUsd));
        vm.assume(oracle != address(mockOracles.token2ToUsd));
        vm.assume(oracle != address(mockOracles.stable1ToUsd));
        vm.assume(oracle != address(mockOracles.stable2ToUsd));
        assertFalse(oracleHub.isActive(address(oracle)));
    }

    function test_isActive_positive() public {
        vm.prank(users.creatorAddress);
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

        assertTrue(oracleHub.isActive(address(mockOracles.token3ToToken4)));
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
