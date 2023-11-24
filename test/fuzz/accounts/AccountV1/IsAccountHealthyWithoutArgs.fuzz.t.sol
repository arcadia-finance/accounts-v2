/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAccountHealthy()" of contract "AccountV1".
 */
contract IsAccountHealthyWithoutArgs_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
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

    function testFuzz_Success_isAccountHealthy_InsufficientMargin(
        uint256 debtInitial,
        uint112 collateralValue,
        uint256 fixedLiquidationCost
    ) public {
        // No overflow of Used Margin.
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint256).max - debtInitial);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        uint256 usedMargin = debtInitial + fixedLiquidationCost;

        // Given: Insufficient margin
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

        // When: Calling isAccountHealthy()
        (bool success, address creditor, uint256 version) = accountExtension.isAccountHealthy();

        // Then: The Account should not be healthy.
        assertTrue(!success);
        assertEq(creditor, address(creditorStable1));
        assertEq(version, 1);
    }

    function testFuzz_Success_isAccountHealthy_SufficientMargin(
        uint256 debtInitial,
        uint112 collateralValue,
        uint256 fixedLiquidationCost
    ) public {
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Given: Sufficient margin
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, collateralValue);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        debtInitial = bound(debtInitial, 0, collateralValue - fixedLiquidationCost);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), debtInitial);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // When: Calling isAccountHealthy()
        (bool success, address creditor, uint256 version) = accountExtension.isAccountHealthy();

        // Then: Account should be healthy.
        assertTrue(success);
        assertEq(creditor, address(creditorStable1));
        assertEq(version, 1);
    }
}
