/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./_AccountV1.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "getUsedMargin" of contract "AccountV1".
 */
contract GetUsedMargin_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

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
    function testFuzz_Success_getUsedMargin_TrustedCreditorNotSet(uint256 openDebt, uint96 fixedLiquidationCost)
        public
    {
        // Test-case: trusted creditor is not set.
        accountExtension.setIsTrustedCreditorSet(false);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        trustedCreditor.setOpenPosition(address(accountExtension), openDebt);

        assertEq(0, accountExtension.getUsedMargin());
    }

    function testFuzz_Success_getUsedMargin_TrustedCreditorIsSet(uint256 openDebt, uint96 fixedLiquidationCost)
        public
    {
        // No overflow of Used Margin.
        vm.assume(openDebt <= type(uint256).max - fixedLiquidationCost);

        // Test-case: trusted creditor set.

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        trustedCreditor.setOpenPosition(address(accountExtension), openDebt);

        assertEq(openDebt + fixedLiquidationCost, accountExtension.getUsedMargin());
    }
}
