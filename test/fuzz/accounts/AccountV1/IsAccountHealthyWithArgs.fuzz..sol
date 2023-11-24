/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAccountHealthy(uint256,uint256)" of contract "AccountV1".
 */
contract IsAccountHealthyWithArgs_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
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

    function testFuzz_Success_isAccountHealthy_debtIncrease_InsufficientMargin(
        uint256 debtInitial,
        uint256 debtIncrease,
        uint112 collateralValue,
        uint256 fixedLiquidationCost
    ) public {
        // No overflow of Used Margin.
        debtIncrease = bound(debtIncrease, 0, type(uint256).max - debtInitial);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint256).max - debtInitial - debtIncrease);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        uint256 usedMargin = debtInitial + fixedLiquidationCost + debtIncrease;

        // test-case: Insufficient margin
        vm.assume(usedMargin > 0);
        collateralValue = uint112(bound(collateralValue, 0, usedMargin - 1));
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), debtInitial);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // When: An Authorised protocol tries to take more margin against the Account.
        (bool success, address creditor, uint256 version) = accountExtension.isAccountHealthy(debtIncrease, 0);

        // Then: The action is not successful.
        assertTrue(!success);
        assertEq(creditor, address(creditorStable1));
        assertEq(version, 1);
    }

    function testFuzz_Success_isAccountHealthy_debtIncrease_SufficientMargin(
        uint256 debtInitial,
        uint256 debtIncrease,
        uint112 collateralValue,
        uint256 fixedLiquidationCost
    ) public {
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // test-case: Sufficient margin
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, collateralValue);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        debtInitial = bound(debtInitial, 0, collateralValue - fixedLiquidationCost);
        debtIncrease = bound(debtIncrease, 0, collateralValue - fixedLiquidationCost - debtInitial);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), debtInitial);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // When: An Authorised protocol tries to take more margin against the Account
        (bool success, address creditor, uint256 version) = accountExtension.isAccountHealthy(debtIncrease, 0);

        // Then: The action is successful
        assertTrue(success);
        assertEq(creditor, address(creditorStable1));
        assertEq(version, 1);
    }

    function testFuzz_Success_isAccountHealthy_totalOpenDebt_InsufficientMargin(
        uint256 debt,
        uint112 collateralValue,
        uint256 fixedLiquidationCost
    ) public {
        // No overflow of Used Margin.
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint256).max - debt);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        uint256 usedMargin = debt + fixedLiquidationCost;

        // test-case: Insufficient margin
        vm.assume(usedMargin > 0);
        collateralValue = uint112(bound(collateralValue, 0, usedMargin - 1));
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // When: An Authorised protocol tries to take more margin against the Account
        (bool success, address creditor, uint256 version) = accountExtension.isAccountHealthy(0, debt);

        // Then: The action is not successful
        assertTrue(!success);
        assertEq(creditor, address(creditorStable1));
        assertEq(version, 1);
    }

    function testFuzz_Success_isAccountHealthy_totalOpenDebt_SufficientMargin(
        uint256 debt,
        uint112 collateralValue,
        uint256 fixedLiquidationCost
    ) public {
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));
        // test-case: Sufficient margin
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, collateralValue);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        debt = bound(debt, 0, collateralValue - fixedLiquidationCost);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // When: An Authorised protocol tries to take more margin against the Account
        (bool success, address creditor, uint256 version) = accountExtension.isAccountHealthy(0, debt);

        // Then: The action is successful
        assertTrue(success);
        assertEq(creditor, address(creditorStable1));
        assertEq(version, 1);
    }
}
