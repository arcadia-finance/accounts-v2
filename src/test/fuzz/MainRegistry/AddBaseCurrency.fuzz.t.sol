/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, MainRegistry_Fuzz_Test } from "./MainRegistry.fuzz.t.sol";

import { MainRegistry } from "../../../MainRegistry.sol";

/**
 * @notice Fuzz tests for the "addBaseCurrency" of contract "MainRegistry".
 */
contract AddBaseCurrency_MainRegistry_Fuzz_Test is MainRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        MainRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_addBaseCurrency_NonOwner(address unprivilegedAddress_) public {
        // Given: unprivilegedAddress_ is not users.creatorAddress
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        // When: unprivilegedAddress_ calls addBaseCurrency

        // Then: addBaseCurrency should revert with "UNAUTHORIZED"
        vm.expectRevert("UNAUTHORIZED");
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        vm.stopPrank();
    }

    function testRevert_addBaseCurrency_duplicateBaseCurrency() public {
        vm.startPrank(users.creatorAddress);
        // Given: users.creatorAddress calls addBaseCurrency
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );

        // When: users.creatorAddress calls addBaseCurrency again with the same baseCurrency
        // then: addBaseCurrency should revert with "MR_ABC: BaseCurrency exists"
        vm.expectRevert("MR_ABC: BaseCurrency exists");
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );
        vm.stopPrank();
    }

    function testSuccess_addBaseCurrency() public {
        // When: users.creatorAddress calls addBaseCurrency
        vm.prank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit BaseCurrencyAdded(address(mockERC20.stable2), 4, "STABLE2");
        mainRegistryExtension.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.stableOracleDecimals),
                assetAddress: address(mockERC20.stable2),
                baseCurrencyToUsdOracle: address(mockOracles.stable2ToUsd),
                baseCurrencyLabel: "STABLE2",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.tokenDecimals))
            })
        );

        // Then: baseCurrencyCounter should return 2
        assertEq(4, mainRegistryExtension.baseCurrencyCounter());
    }
}
