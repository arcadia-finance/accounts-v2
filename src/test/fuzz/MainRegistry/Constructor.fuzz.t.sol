/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./_MainRegistry.fuzz.t.sol";

import { MainRegistry } from "../../../MainRegistry.sol";

/**
 * @notice Fuzz tests for the "constructor" of contract "MainRegistry".
 */
contract Constructor_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment() public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit BaseCurrencyAdded(address(0), 0, "USD");
        MainRegistry mainRegistry = new MainRegistry(address(factory));
        vm.stopPrank();

        assertEq(mainRegistry.factory(), address(factory));
        (
            uint64 baseCurrencyUnitCorrection,
            address assetaddress,
            uint64 baseCurrencyToUsdOracleUnit,
            address baseCurrencyToUsdOracle,
            bytes8 baseCurrencyLabel
        ) = mainRegistry.baseCurrencyToInformation(0);
        assertEq(baseCurrencyUnitCorrection, 1);
        assertEq(assetaddress, address(0));
        assertEq(baseCurrencyToUsdOracleUnit, 1);
        assertEq(baseCurrencyToUsdOracle, address(0));
        assertTrue(bytes8("USD") == baseCurrencyLabel);
        assertEq(mainRegistry.assetToBaseCurrency(address(0)), 0);
        assertEq(mainRegistry.baseCurrencies(0), address(0));
        assertEq(mainRegistry.baseCurrencyCounter(), 1);
    }
}
