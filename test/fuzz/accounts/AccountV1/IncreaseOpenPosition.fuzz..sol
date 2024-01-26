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
        uint256 minimumMargin
    ) public {
        // Debt is non-zero.
        debt = bound(debt, 1, type(uint256).max);

        // No overflow of Used Margin.
        minimumMargin = bound(minimumMargin, 0, type(uint256).max - debt);
        minimumMargin = bound(minimumMargin, 0, type(uint96).max);
        uint256 usedMargin = debt + minimumMargin;

        // test-case: Insufficient margin
        vm.assume(usedMargin > 0);
        collateralValue = uint112(bound(collateralValue, 0, usedMargin - 1));
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // When: An Authorised protocol tries to take more margin against the Account
        // Then: Transaction should revert with AccountErrors.AccountUnhealthy.selector.
        vm.prank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        accountExtension.increaseOpenPosition(debt);
    }

    function testFuzz_Revert_increaseOpenPosition_inAuction(uint256 openPosition) public {
        // Will set "inAuction" to true.
        accountExtension.setInAuction();

        // Confirm the accountExtension has creditorStable1 set.
        assertEq(accountExtension.creditor(), address(creditorStable1));

        // Should revert if the Account is in an auction.
        vm.startPrank(address(creditorStable1));
        vm.expectRevert(AccountErrors.AccountInAuction.selector);
        accountExtension.increaseOpenPosition(openPosition);
        vm.stopPrank();
    }

    function testFuzz_Success_increaseOpenPosition(
        uint256 debt,
        uint112 collateralValue,
        uint256 minimumMargin,
        uint32 time
    ) public {
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));
        // test-case: Sufficient margin
        minimumMargin = bound(minimumMargin, 0, collateralValue);
        minimumMargin = bound(minimumMargin, 0, type(uint96).max);
        debt = bound(debt, 0, collateralValue - minimumMargin);

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // Warp time
        time = uint32(bound(time, 2 days, type(uint32).max));
        vm.warp(time);
        // Update updatedAt to avoid InactiveOracle() reverts.
        vm.prank(users.defaultTransmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // When: The Creditor tries to take more margin against the Account
        vm.prank(address(creditorStable1));
        uint256 version = accountExtension.increaseOpenPosition(debt);

        // Then: The action is successful
        assertEq(version, 1);

        // And: lastActionTimestamp is updated.
        assertEq(accountExtension.lastActionTimestamp(), time);
    }
}
