/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import "../src/InterestRateModule.sol";

contract InterestRateModuleExtension is InterestRateModule {
    //Extensions to test internal functions

    function setInterestConfig(InterestRateConfiguration calldata newConfig) public {
        _setInterestConfig(newConfig);
    }

    function calculateInterestRate(uint256 utilisation) public view returns (uint256) {
        return _calculateInterestRate(utilisation);
    }

    function updateInterestRate(uint256 realisedDebt_, uint256 totalRealisedLiquidity_) public {
        return _updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
    }
}

contract InterestRateModuleTest is Test {
    InterestRateModuleExtension interest;

    event InterestRate(uint80 interestRate);

    //Before Each
    function setUp() public virtual {
        interest = new InterestRateModuleExtension();
    }

    function testSuccess_setInterestConfig(
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint8 utilisationThreshold_
    ) public {
        // Given: A certain InterestRateConfiguration
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });
        // When: The InterestConfiguration is set
        interest.setInterestConfig(config);

        // Then: config types should be equal to fuzzed types
        (uint256 baseRatePerYear, uint256 lowSlopePerYear, uint256 highSlopePerYear, uint256 utilisationThreshold) =
            interest.interestRateConfig();
        assertEq(baseRatePerYear, baseRate_);
        assertEq(highSlopePerYear, highSlope_);
        assertEq(lowSlopePerYear, lowSlope_);
        assertEq(utilisationThreshold, utilisationThreshold_);
    }

    function testSuccess_updateInterestRate_totalRealisedLiquidityMoreThanZero(
        uint128 realisedDebt_,
        uint128 totalRealisedLiquidity_,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint40 utilisationThreshold_
    ) public {
        // Given: totalRealisedLiquidity_ is more than equal to 0, baseRate_ is less than 100000, highSlope_ is bigger than lowSlope_
        vm.assume(totalRealisedLiquidity_ > 0);
        vm.assume(realisedDebt_ <= type(uint128).max / (10 ** 5));
        vm.assume(realisedDebt_ <= totalRealisedLiquidity_);
        vm.assume(utilisationThreshold_ <= 100_000);

        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: The InterestConfiguration is set
        interest.setInterestConfig(config);

        // And: utilisation is 100_000 multiplied by realisedDebt_ and divided by totalRealisedLiquidity_
        uint256 utilisation = (100_000 * realisedDebt_) / totalRealisedLiquidity_;

        uint256 expectedInterestRate;

        if (utilisation <= utilisationThreshold_) {
            // And: expectedInterestRate is lowSlope multiplied by utilisation, divided by 100000 and added to baseRate
            expectedInterestRate = uint256(baseRate_) + uint256(lowSlope_) * utilisation / 100_000;
        } else {
            // And: lowSlopeInterest is utilisationThreshold multiplied by lowSlope,
            // highSlopeInterest is utilisation minus utilisationThreshold multiplied by highSlope
            uint256 lowSlopeInterest = uint256(utilisationThreshold_) * lowSlope_;
            uint256 highSlopeInterest = uint256(utilisation - config.utilisationThreshold) * highSlope_;

            // And: expectedInterestRate is baseRate added to lowSlopeInterest added to highSlopeInterest divided by 100000
            expectedInterestRate = uint256(baseRate_) + (lowSlopeInterest + highSlopeInterest) / 100_000;
        }

        assertTrue(expectedInterestRate <= type(uint80).max);

        vm.expectEmit(true, true, true, true);
        emit InterestRate(uint80(expectedInterestRate));
        interest.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
        uint256 actualInterestRate = interest.interestRate();

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }

    function testSuccess_updateInterestRate_totalRealisedLiquidityZero(
        uint256 realisedDebt_,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint40 utilisationThreshold_
    ) public {
        // Given: totalRealisedLiquidity_ is equal to 0, baseRate_ is less than 100000, highSlope_ is bigger than lowSlope_
        uint256 totalRealisedLiquidity_ = 0;
        vm.assume(realisedDebt_ <= type(uint128).max / (10 ** 5)); //highest possible debt at 1000% over 5 years: 3402823669209384912995114146594816
        vm.assume(utilisationThreshold_ <= 100_000);

        // And: a certain InterestRateConfiguration
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: The InterestConfiguration is set
        interest.setInterestConfig(config);
        // And: The interest is set for a certain combination of realisedDebt_ and totalRealisedLiquidity_
        interest.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);

        uint256 expectedInterestRate = baseRate_;

        vm.expectEmit(true, true, true, true);
        emit InterestRate(uint80(expectedInterestRate));
        interest.updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
        uint256 actualInterestRate = interest.interestRate();

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }

    function testSuccess_calculateInterestRate_UnderOptimalUtilisation(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint40 utilisationThreshold_
    ) public {
        // Given: utilisation is between 0 and 80000, baseRate_ is less than 100000, highSlope_ is bigger than lowSlope_
        vm.assume(utilisationThreshold_ <= 100_000);
        vm.assume(utilisation <= utilisationThreshold_);

        // And: a certain InterestRateConfiguration
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: The InterestConfiguration is set
        interest.setInterestConfig(config);

        // And: actualInterestRate is calculateInterestRate with utilisation
        uint256 actualInterestRate = interest.calculateInterestRate(utilisation);

        // And: expectedInterestRate is lowSlope multiplied by utilisation divided by 100000 and added to baseRate
        uint256 expectedInterestRate = uint256(baseRate_) + uint256(lowSlope_) * utilisation / 100_000;

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }

    function testSuccess_calculateInterestRate_OverOptimalUtilisation(
        uint40 utilisation,
        uint72 baseRate_,
        uint72 highSlope_,
        uint72 lowSlope_,
        uint40 utilisationThreshold_
    ) public {
        // Given: utilisation is between 80000 and 100000, highSlope_ is bigger than lowSlope_
        vm.assume(utilisationThreshold_ <= 100_000);
        vm.assume(utilisation > utilisationThreshold_);

        // And: a certain InterestRateConfiguration
        InterestRateModule.InterestRateConfiguration memory config = InterestRateModule.InterestRateConfiguration({
            baseRatePerYear: baseRate_,
            highSlopePerYear: highSlope_,
            lowSlopePerYear: lowSlope_,
            utilisationThreshold: utilisationThreshold_
        });

        // When: The InterestConfiguration is set
        interest.setInterestConfig(config);

        // And: lowSlopeInterest is utilisationThreshold multiplied by lowSlope, highSlopeInterest is utilisation minus utilisationThreshold multiplied by highSlope
        uint256 lowSlopeInterest = uint256(utilisationThreshold_) * lowSlope_;
        uint256 highSlopeInterest = uint256(utilisation - utilisationThreshold_) * highSlope_;

        // And: expectedInterestRate is baseRate added to lowSlopeInterest added to highSlopeInterest divided by divided by 100000
        uint256 expectedInterestRate = uint256(baseRate_) + (lowSlopeInterest + highSlopeInterest) / 100_000;

        // And: actualInterestRate is calculateInterestRate with utilisation
        uint256 actualInterestRate = interest.calculateInterestRate(utilisation);

        // Then: actualInterestRate should be equal to expectedInterestRate
        assertEq(actualInterestRate, expectedInterestRate);
    }
}
