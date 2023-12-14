/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { AccountErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "increaseOpenPosition" of contract "AccountV1".
 */
contract IncreaseOpenPosition_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
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

    function testFuzz_Revert_increaseOpenPosition_NonCreditor(address nonCreditor, uint256 debt) public {
        vm.assume(nonCreditor != address(creditorStable1));

        vm.prank(nonCreditor);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        accountExtension.increaseOpenPosition(debt);
    }

    function testFuzz_Revert_increaseOpenPosition_Reentered(uint256 debt) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        vm.startPrank(address(creditorStable1));
        vm.expectRevert(AccountErrors.NoReentry.selector);
        accountExtension.increaseOpenPosition(debt);
    }

    function testFuzz_Revert_increaseOpenPosition_InsufficientMargin(
        uint256 debt,
        uint112 collateralValue,
        uint256 fixedLiquidationCost
    ) public {
        // Debt is non-zero.
        debt = bound(debt, 1, type(uint256).max);

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
        // Then: Transaction should revert with AccountErrors.AccountUnhealthy.selector.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountExtension.increaseOpenPosition(debt);
    }

    function testFuzz_Success_increaseOpenPosition(
        uint256 debt,
        uint112 collateralValue,
        uint256 fixedLiquidationCost,
        uint32 time
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

        vm.warp(time);

        // When: The Creditor tries to take more margin against the Account
        vm.prank(address(creditorStable1));
        uint256 version = accountExtension.increaseOpenPosition(debt);

        // Then: The action is successful
        assertEq(version, 1);

        // And: lastActionTimestamp is updated.
        assertEq(accountExtension.lastActionTimestamp(), time);
    }
}
