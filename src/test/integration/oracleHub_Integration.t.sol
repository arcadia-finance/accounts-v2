/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test, Constants } from "../Base_IntegrationAndUnit.t.sol";
import { OracleHub_UsdOnly } from "../../OracleHub_UsdOnly.sol";

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
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_getRateInUsd_NegativeRate(int256 rateToken1ToUsd) public {
        // Given: oracleToken1ToUsdDecimals less than equal to 18, rateToken1ToUsd less than equal to max uint256 value,
        // rateToken1ToUsd is less than max uint256 value divided by WAD
        vm.assume(rateToken1ToUsd < 0);

        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(rateToken1ToUsd);
        vm.stopPrank();

        vm.expectRevert("OH_GR: Negative Rate");
        oracleHub.getRateInUsd(oracleToken1ToUsdArr);
    }

    function testRevert_getRate_NoUsdOrBaseCurrencyOracle() public {
        vm.expectRevert("OH_GR: No qAsset in USD or bCurr");
        oracleHub.getRateInUsd(new address[](0));
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

    function testFuzz_Revert_getRateInUsd_SingleOracleOverflow(uint256 rateToken4ToUsd, uint8 oracleToken4ToUsdDecimals)
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

        // Then: getRate should revert with Arithmetic overflow
        vm.expectRevert(bytes(""));
        oracleHub.getRateInUsd(oracleToken4ToUsdArr);
    }

    function testFuzz_getRateInUsd_MultipleOracles(
        uint256 rateToken3ToToken1,
        uint256 rateToken4ToUsd,
        uint8 oracleToken3ToToken1Decimals,
        uint8 oracleToken4ToUsdDecimals
    ) public {
        // Given: oracleToken3ToToken1Decimals and oracleToken4ToUsdDecimals is less than equal to 18,
        // rateToken3ToToken1 and rateToken4ToUsd is less than equal to uint256 max value, rateToken3ToToken1 is less than equal to uint256 max value divided by WAD
        vm.assume(oracleToken3ToToken1Decimals <= 18 && oracleToken4ToUsdDecimals <= 18);

        vm.assume(rateToken3ToToken1 <= uint256(type(int256).max));
        vm.assume(rateToken4ToUsd <= uint256(type(int256).max));

        vm.assume(rateToken3ToToken1 <= type(uint256).max / Constants.WAD);

        if (rateToken3ToToken1 == 0) {
            vm.assume(uint256(rateToken4ToUsd) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(rateToken4ToUsd)
                    <= type(uint256).max / Constants.WAD * 10 ** oracleToken3ToToken1Decimals / uint256(rateToken3ToToken1)
            );
        }

        // When: creatorAddress addOracle for TOKEN3-TOKEN1 and TOKEN4-USD, oracleOwner transmit rateToken3ToToken1 and rateToken4ToUsd,
        // oraclesToken3ToUsd index 0 is oracleToken3ToToken1, oraclesToken3ToUsd index 1 is oracleToken4ToUsd
        vm.startPrank(users.creatorAddress);
        oracleHub.addOracle(
            OracleHub_UsdOnly.OracleInformation({
                oracleUnit: uint64(10 ** oracleToken3ToToken1Decimals),
                baseAsset: "TOKEN3",
                quoteAsset: "TOKEN1",
                oracle: address(mockOracles.token3ToToken1),
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
        mockOracles.token3ToToken1.transmit(int256(rateToken3ToToken1));
        mockOracles.token4ToUsd.transmit(int256(rateToken4ToUsd));
        vm.stopPrank();

        uint256 expectedRateInUsd = (
            ((Constants.WAD * uint256(rateToken3ToToken1)) / 10 ** (oracleToken3ToToken1Decimals))
                * uint256(rateToken4ToUsd)
        ) / 10 ** (oracleToken4ToUsdDecimals);

        address[] memory oracleToken3ToUsdArr = new address[](2);
        oracleToken3ToUsdArr[0] = address(mockOracles.token3ToToken1);
        oracleToken3ToUsdArr[1] = address(mockOracles.token4ToUsd);
        uint256 actualRateInUsd = oracleHub.getRateInUsd(oracleToken3ToUsdArr);

        // Then: expectedRateInUsd should be equal to actualRateInUsd
        assertEq(expectedRateInUsd, actualRateInUsd);
    }
}
