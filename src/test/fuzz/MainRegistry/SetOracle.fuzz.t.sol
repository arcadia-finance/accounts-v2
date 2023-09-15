/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { MainRegistry } from "../../../MainRegistry.sol";
import { RevertingOracle } from "../../mocks/RevertingOracle.sol";

/**
 * @notice Fuzz tests for the "setOracle" of contract "MainRegistry".
 */
contract SetOracle_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_setOracle_NonOwner(
        uint256 baseCurrency,
        address newOracle,
        uint64 baseCurrencyToUsdOracleUnit,
        address unprivilegedAddress_
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        mainRegistryExtension.setOracle(baseCurrency, newOracle, baseCurrencyToUsdOracleUnit);
        vm.stopPrank();
    }

    function testRevert_setOracle_NonBaseCurrency(
        uint256 baseCurrency,
        address newOracle,
        uint64 baseCurrencyToUsdOracleUnit
    ) public {
        vm.assume(baseCurrency >= mainRegistryExtension.baseCurrencyCounter());

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("MR_SO: UNKNOWN_BASECURRENCY");
        mainRegistryExtension.setOracle(baseCurrency, newOracle, baseCurrencyToUsdOracleUnit);
        vm.stopPrank();
    }

    function testRevert_setOracle_HealthyOracle(
        address newOracle,
        uint64 baseCurrencyToUsdOracleUnit,
        int192 minAnswer,
        int192 maxAnswer,
        int256 price,
        uint24 timePassed
    ) public {
        vm.assume(minAnswer >= 0);
        vm.assume(price > minAnswer);
        vm.assume(price < maxAnswer);
        vm.assume(timePassed <= 1 weeks);

        vm.prank(users.creatorAddress);
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        uint256 baseCurrency = mainRegistryExtension.assetToBaseCurrency(address(mockERC20.stable2));

        vm.warp(2 weeks); //to not run into an underflow

        vm.prank(users.defaultTransmitter);
        mockOracles.stable2ToUsd.transmit(price);
        mockOracles.stable2ToUsd.setMinAnswer(minAnswer);
        mockOracles.stable2ToUsd.setMaxAnswer(maxAnswer);

        vm.warp(block.timestamp + timePassed);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("MR_SO: ORACLE_HEALTHY");
        mainRegistryExtension.setOracle(baseCurrency, newOracle, baseCurrencyToUsdOracleUnit);
        vm.stopPrank();
    }

    function testSuccess_setOracle_RevertingOracle(address newOracle, uint64 baseCurrencyToUsdOracleUnit) public {
        RevertingOracle revertingOracle = new RevertingOracle();

        vm.prank(users.creatorAddress);
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(revertingOracle),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        uint256 baseCurrency = mainRegistryExtension.assetToBaseCurrency(address(mockERC20.stable2));

        vm.prank(users.creatorAddress);
        mainRegistryExtension.setOracle(baseCurrency, newOracle, baseCurrencyToUsdOracleUnit);

        (,, uint64 baseCurrencyToUsdOracleUnit_, address oracle,) =
            mainRegistryExtension.baseCurrencyToInformation(baseCurrency);
        assertEq(oracle, newOracle);
        assertEq(baseCurrencyToUsdOracleUnit_, baseCurrencyToUsdOracleUnit);
    }

    function testSuccess_setOracle_MinAnswer(
        address newOracle,
        uint64 baseCurrencyToUsdOracleUnit,
        int192 minAnswer,
        int192 price
    ) public {
        vm.assume(minAnswer >= 0);
        vm.assume(price <= minAnswer);

        vm.prank(users.creatorAddress);
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        uint256 baseCurrency = mainRegistryExtension.assetToBaseCurrency(address(mockERC20.stable2));

        vm.prank(users.defaultTransmitter);
        mockOracles.stable2ToUsd.transmit(price);
        mockOracles.stable2ToUsd.setMinAnswer(minAnswer);
        mockOracles.stable2ToUsd.setMaxAnswer(type(int192).max);

        vm.prank(users.creatorAddress);
        mainRegistryExtension.setOracle(baseCurrency, newOracle, baseCurrencyToUsdOracleUnit);

        (,, uint64 baseCurrencyToUsdOracleUnit_, address oracle,) =
            mainRegistryExtension.baseCurrencyToInformation(baseCurrency);
        assertEq(oracle, newOracle);
        assertEq(baseCurrencyToUsdOracleUnit_, baseCurrencyToUsdOracleUnit);
    }

    function testSuccess_setOracle_MaxAnswer(
        address newOracle,
        uint64 baseCurrencyToUsdOracleUnit,
        int192 maxAnswer,
        int256 price
    ) public {
        vm.assume(maxAnswer >= 0);
        vm.assume(price >= maxAnswer);

        vm.prank(users.creatorAddress);
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        uint256 baseCurrency = mainRegistryExtension.assetToBaseCurrency(address(mockERC20.stable2));

        vm.prank(users.defaultTransmitter);
        mockOracles.stable2ToUsd.transmit(price);
        mockOracles.stable2ToUsd.setMinAnswer(0);
        mockOracles.stable2ToUsd.setMaxAnswer(maxAnswer);

        vm.prank(users.creatorAddress);
        mainRegistryExtension.setOracle(baseCurrency, newOracle, baseCurrencyToUsdOracleUnit);

        (,, uint64 baseCurrencyToUsdOracleUnit_, address oracle,) =
            mainRegistryExtension.baseCurrencyToInformation(baseCurrency);
        assertEq(oracle, newOracle);
        assertEq(baseCurrencyToUsdOracleUnit_, baseCurrencyToUsdOracleUnit);
    }

    function testSuccess_setOracle_UpdateTooOld(
        address newOracle,
        uint64 baseCurrencyToUsdOracleUnit,
        int192 minAnswer,
        int192 maxAnswer,
        int256 price,
        uint32 timePassed
    ) public {
        vm.assume(minAnswer >= 0);
        vm.assume(price >= minAnswer);
        vm.assume(price <= maxAnswer);
        vm.assume(timePassed > 1 weeks);

        vm.prank(users.creatorAddress);
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        uint256 baseCurrency = mainRegistryExtension.assetToBaseCurrency(address(mockERC20.stable2));

        vm.warp(2 weeks); //to not run into an underflow

        vm.prank(users.defaultTransmitter);
        mockOracles.stable2ToUsd.transmit(price);
        mockOracles.stable2ToUsd.setMinAnswer(minAnswer);
        mockOracles.stable2ToUsd.setMaxAnswer(maxAnswer);

        vm.warp(block.timestamp + timePassed);

        vm.prank(users.creatorAddress);
        mainRegistryExtension.setOracle(baseCurrency, newOracle, baseCurrencyToUsdOracleUnit);

        (,, uint64 baseCurrencyToUsdOracleUnit_, address oracle,) =
            mainRegistryExtension.baseCurrencyToInformation(baseCurrency);
        assertEq(oracle, newOracle);
        assertEq(baseCurrencyToUsdOracleUnit_, baseCurrencyToUsdOracleUnit);
    }
}
