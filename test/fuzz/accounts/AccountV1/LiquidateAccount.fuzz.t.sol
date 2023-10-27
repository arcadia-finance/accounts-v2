/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "liquidateAccount" of contract "AccountV1".
 */
contract LiquidateAccount_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();

        // Given: Trusted Creditor is set.
        openMarginAccount();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_liquidateAccount_Reentered(uint128 debt) public {
        // Reentrancy guard is in locked state.
        accountExtension.setLocked(2);

        // Should revert if the reentrancy guard is locked.
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A: REENTRANCY");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotAuthorized(uint128 debt, address unprivilegedAddress) public {
        // msg.sender is different from the Liquidator.
        vm.assume(unprivilegedAddress != accountExtension.liquidator());

        // Should revert if not called by the Liquidator
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("A_LA: Only Liquidator");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_AccountIsHealthy(
        uint128 debt,
        uint128 liquidationValue,
        uint96 fixedLiquidationCost
    ) public {
        // Assume account is healthy: liquidationValue is bigger than usedMargin (debt + fixedLiquidationCost).
        uint256 usedMargin = uint256(debt) + fixedLiquidationCost;
        vm.assume(liquidationValue >= usedMargin);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(fixedLiquidationCost);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, liquidationValue);

        // Should revert if account is healthy.
        vm.startPrank(accountExtension.liquidator());
        vm.expectRevert("A_LA: liqValue above usedMargin");
        accountExtension.liquidateAccount(debt);
        vm.stopPrank();
    }

    function testFuzz_Success_liquidateAccount_Unhealthy(
        uint128 debt,
        uint128 liquidationValue,
        uint96 fixedLiquidationCost
    ) public {
        // Assume account is unhealthy: liquidationValue is smaller than usedMargin (debt + fixedLiquidationCost).
        uint256 usedMargin = uint256(debt) + fixedLiquidationCost;
        vm.assume(liquidationValue < usedMargin);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(fixedLiquidationCost);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, liquidationValue);

        // Should liquidate the Account.
        vm.startPrank(accountExtension.liquidator());
        vm.expectEmit(true, true, true, true);
        emit TrustedMarginAccountChanged(address(0), address(0));
        (address originalOwner, address baseCurrency, address trustedCreditor_) =
            accountExtension.liquidateAccount(debt);
        vm.stopPrank();

        assertEq(originalOwner, users.accountOwner);
        assertEq(baseCurrency, address(mockERC20.stable1));
        assertEq(trustedCreditor_, address(creditorStable1));

        assertEq(accountExtension.owner(), Constants.initLiquidator);
        assertEq(accountExtension.isTrustedCreditorSet(), false);
        assertEq(accountExtension.trustedCreditor(), address(0));
        assertEq(accountExtension.fixedLiquidationCost(), 0);
    }
}
