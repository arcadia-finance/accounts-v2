/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getFreeMargin" of contract "AccountV1".
 */
contract GetFreeMargin_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        // Given: Creditor is set.
        openMarginAccount();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    // TODO: add processDeposit and withdrawal when opening and closing a margin account.
    /*     function testFuzz_Success_getFreeMargin_CreditorNotSet(
        uint256 openDebt,
        uint256 fixedLiquidationCost,
        uint128 collateralValue
    ) public {
        // Test-case: creditor is not set.
        accountExtension.setCreditor(address(0));

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), openDebt);

        // Given: "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        assertEq(collateralValue, accountExtension.getFreeMargin());
    } */

    function testFuzz_Success_getFreeMargin_CreditorIsSet_NonZeroFreeMargin(
        uint256 openDebt,
        uint256 fixedLiquidationCost,
        uint112 collateralValue
    ) public {
        // No overflow of Used Margin.
        vm.assume(openDebt <= type(uint256).max - fixedLiquidationCost);

        // "exposure" is strictly smaller than "maxExposure" -> collateralValue < type(uint128).max.
        // Non zero free margin -> "collateralValue" bigger than "usedMargin".
        collateralValue = uint112(bound(collateralValue, 1, type(uint112).max - 1));
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, collateralValue - 1);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        openDebt = bound(openDebt, 0, collateralValue - fixedLiquidationCost - 1);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), openDebt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        assertEq(collateralValue - openDebt - fixedLiquidationCost, accountExtension.getFreeMargin());
    }

    function testFuzz_Success_getFreeMargin_CreditorIsSet_ZeroFreeMargin(
        uint256 openDebt,
        uint256 fixedLiquidationCost,
        uint112 collateralValue
    ) public {
        // No overflow of Used Margin.
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint256).max - openDebt);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        uint256 usedMargin = openDebt + fixedLiquidationCost;

        // Zero free margin -> "collateralValue" smaller or equal as "usedMargin".
        collateralValue = uint112(bound(collateralValue, 0, usedMargin));
        // "exposure" is strictly smaller than "maxExposure" -> collateralValue < type(uint128).max.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), openDebt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        assertEq(0, accountExtension.getFreeMargin());
    }
}
