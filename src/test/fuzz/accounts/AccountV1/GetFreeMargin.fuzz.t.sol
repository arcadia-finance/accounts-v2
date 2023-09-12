/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, AccountV1_Fuzz_Test } from "./AccountV1.fuzz.t.sol";

import { RiskConstants } from "../../../../utils/RiskConstants.sol";

/**
 * @notice Fuzz tests for the "getFreeMargin" of contract "AccountV1".
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

        // Given: Trusted Creditor is set.
        openMarginAccount();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_getFreeMargin_TrustedCreditorNotSet(
        uint256 openDebt,
        uint256 fixedLiquidationCost,
        uint256 collateralValue
    ) public {
        // Test-case: trusted creditor is not set.
        accountExtension.setIsTrustedCreditorSet(false);

        // No overflow riskmodule
        collateralValue = bound(collateralValue, 1, type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        trustedCreditor.setOpenPosition(address(accountExtension), openDebt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        assertEq(collateralValue, accountExtension.getFreeMargin());
    }

    function testSuccess_getFreeMargin_TrustedCreditorIsSet_NonZeroFreeMargin(
        uint256 openDebt,
        uint256 fixedLiquidationCost,
        uint256 collateralValue
    ) public {
        // No overflow riskmodule
        collateralValue = bound(collateralValue, 1, type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT);

        // No overflow of Used Margin.
        vm.assume(openDebt <= type(uint256).max - fixedLiquidationCost);

        // Non zero free margin -> "collateralValue" bigger as "usedMargin".
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, collateralValue - 1);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        openDebt = bound(openDebt, 0, collateralValue - fixedLiquidationCost - 1);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        trustedCreditor.setOpenPosition(address(accountExtension), openDebt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        assertEq(collateralValue - openDebt - fixedLiquidationCost, accountExtension.getFreeMargin());
    }

    function testSuccess_getFreeMargin_TrustedCreditorIsSet_ZeroFreeMargin(
        uint256 openDebt,
        uint256 fixedLiquidationCost,
        uint256 collateralValue
    ) public {
        // No overflow of Used Margin.
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint256).max - openDebt);
        fixedLiquidationCost = bound(fixedLiquidationCost, 0, type(uint96).max);
        uint256 usedMargin = openDebt + fixedLiquidationCost;

        // Zero free margin -> "collateralValue" smaller or equal as "usedMargin".
        collateralValue = bound(collateralValue, 0, usedMargin);
        // No overflow riskmodule
        collateralValue = bound(collateralValue, 0, type(uint256).max / RiskConstants.RISK_VARIABLES_UNIT);

        // Set fixedLiquidationCost
        accountExtension.setFixedLiquidationCost(uint96(fixedLiquidationCost));

        // Mock initial debt.
        trustedCreditor.setOpenPosition(address(accountExtension), openDebt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositTokenInAccount(accountExtension, mockERC20.stable1, collateralValue);

        assertEq(0, accountExtension.getFreeMargin());
    }
}
