/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, OracleHub_Fuzz_Test } from "./_OracleHub.fuzz.t.sol";

import { OracleHub } from "../../../OracleHub.sol";

/**
 * @notice Fuzz tests for the function "getRate" of contract "OracleHub".
 */
contract GetRate_OracleHub_Fuzz_Test is OracleHub_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        OracleHub_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
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

    function testRevert_Fuzz_getRateInUsd_FirstOracleOverflowsRate(
        uint256 rateToken4ToUsd,
        uint8 oracleToken4ToUsdDecimals
    ) public {
        // Given: oracleToken4ToUsdDecimals less than equal to 18, rateToken4ToUsd less than equal to max uint256 value,
        // rateToken4ToUsd is more than max uint256 value divided by WAD
        vm.assume(oracleToken4ToUsdDecimals <= 18);
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken4ToUsd > type(uint256).max / Constants.WAD);

        vm.startPrank(users.creatorAddress);
        // When: creatorAddress addOracle with OracleInformation for TOKEN4-USD, oracleOwner transmit rateToken4ToUsd,
        // oraclesToken4ToUsd index 0 is oracleToken4ToUsd, oracleOwner getRate
        oracleHub.addOracle(
            OracleHub.OracleInformation({
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

    function testFuzz_Revert_getRateInUsd_SecondOracleOverflowsRate(
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

        // When: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD, oracleOwner transmit rateToken3ToToken4 and rateToken4ToUsd,
        // oraclesToken3ToUsd index 0 is oracleToken3ToToken4, oraclesToken3ToUsd index 1 is oracleToken4ToUsd
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken3ToToken4Decimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub.OracleInformation({
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

    function testFuzz_Revert_getRateInUsd_ProductOfOraclesOverflowsRate(
        uint256 rateToken3ToToken4,
        uint256 rateToken4ToUsd,
        uint8 oracleToken3ToToken4Decimals,
        uint8 oracleToken4ToUsdDecimals
    ) public {
        // Given: oracleToken3ToToken4Decimals and oracleToken4ToUsdDecimals is less than equal to 18,
        // rateToken3ToToken4 and rateToken4ToUsd is less than equal to uint256 max value, rateToken3ToToken4 is bigger than 0.
        vm.assume(oracleToken3ToToken4Decimals <= 18 && oracleToken4ToUsdDecimals <= 18);
        vm.assume(rateToken3ToToken4 <= type(uint256).max / Constants.WAD);
        vm.assume(rateToken4ToUsd <= type(uint256).max / Constants.WAD);
        vm.assume(rateToken3ToToken4 > 0);

        vm.assume(
            uint256(rateToken4ToUsd)
                > type(uint256).max / Constants.WAD * 10 ** oracleToken3ToToken4Decimals / uint256(rateToken3ToToken4)
        );

        // When: creatorAddress addOracle for TOKEN3-TOKEN4 and TOKEN4-USD, oracleOwner transmit rateToken3ToToken4 and rateToken4ToUsd,
        // oraclesToken3ToUsd index 0 is oracleToken3ToToken4, oraclesToken3ToUsd index 1 is oracleToken4ToUsd
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken3ToToken4Decimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub.OracleInformation({
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

    function testFuzz_Pass_getRateInUsd_SingleOracle(uint256 rateToken4ToUsd, uint8 oracleToken4ToUsdDecimals) public {
        // Given: oracleToken4ToUsdDecimals less than equal to 18, rateToken1ToUsd less than equal to max uint256 value,
        // rateToken1ToUsd is less than max uint256 value divided by WAD
        vm.assume(oracleToken4ToUsdDecimals <= 18);
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));
        vm.assume(rateToken4ToUsd <= type(uint256).max / Constants.WAD);

        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
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

    function testFuzz_Pass_getRateInUsd_MultipleOracles(
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
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken3ToToken4Decimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN4",
                oracle: address(mockOracles.token3ToToken4),
                baseAssetAddress: address(mockERC20.token3),
                isActive: true
            })
        );

        oracleHub.addOracle(
            OracleHub.OracleInformation({
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
