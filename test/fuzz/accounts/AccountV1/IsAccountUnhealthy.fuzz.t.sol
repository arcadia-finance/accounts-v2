/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAccountUnhealthy" of contract "AccountV1".
 */
contract IsAccountUnhealthy_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
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

    function testFuzz_Success_isAccountUnhealthy_InsufficientMargin(
        uint256 debtInitial,
        uint112 collateralValue,
        uint256 minimumMargin
    ) public {
        // Account has open position.
        debtInitial = bound(debtInitial, 1, type(uint256).max);

        // No overflow of Used Margin.
        minimumMargin = bound(minimumMargin, 0, type(uint256).max - debtInitial);
        minimumMargin = bound(minimumMargin, 0, type(uint96).max);
        uint256 usedMargin = debtInitial + minimumMargin;

        // Given: Insufficient margin
        collateralValue = uint112(bound(collateralValue, 0, usedMargin - 1));
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), debtInitial);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // When: Calling isAccountHealthy()
        bool isUnhealthy = accountExtension.isAccountUnhealthy();

        // Then: The Account should not be healthy.
        assertTrue(isUnhealthy);
    }

    function testFuzz_Success_isAccountUnhealthy_SufficientMargin(
        uint256 debtInitial,
        uint112 collateralValue,
        uint256 minimumMargin
    ) public {
        // "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Given: Sufficient margin
        minimumMargin = bound(minimumMargin, 0, collateralValue);
        minimumMargin = bound(minimumMargin, 0, type(uint96).max);
        debtInitial = bound(debtInitial, 0, collateralValue - minimumMargin);

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), debtInitial);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        // When: Calling isAccountHealthy()
        bool isUnhealthy = accountExtension.isAccountUnhealthy();

        // Then: Account should be healthy.
        assertFalse(isUnhealthy);
    }
}
