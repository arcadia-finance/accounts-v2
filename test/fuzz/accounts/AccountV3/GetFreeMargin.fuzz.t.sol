/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountV3_Fuzz_Test } from "./_AccountV3.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "getFreeMargin" of contract "AccountV3".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetFreeMargin_AccountV3_Fuzz_Test is AccountV3_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV3_Fuzz_Test.setUp();

        // Given: Creditor is set.
        openMarginAccount();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getFreeMargin_CreditorNotSet(uint112 collateralValue) public {
        // Given: No creditor is set.
        vm.prank(users.accountOwner);
        accountExtension.closeMarginAccount();

        // And: "exposure" is strictly smaller than "maxExposure".
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // And: Assets are deposited.
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralValue);

        // Then: Without a Creditor no risk factors are set, so the Account has no collateral value
        // and no free margin, independent of the assets deposited.
        assertEq(accountExtension.getUsedMargin(), 0);
        assertEq(accountExtension.getCollateralValue(), 0);
        assertEq(accountExtension.getFreeMargin(), 0);
    }

    function testFuzz_Success_getFreeMargin_CreditorIsSet_NonZeroFreeMargin(
        uint256 openDebt,
        uint256 minimumMargin,
        uint112 collateralValue
    ) public {
        // No overflow of Used Margin.
        vm.assume(openDebt <= type(uint256).max - minimumMargin);

        // "exposure" is strictly smaller than "maxExposure" -> collateralValue < type(uint128).max.
        // Non zero free margin -> "collateralValue" bigger than "usedMargin".
        collateralValue = uint112(bound(collateralValue, 1, type(uint112).max - 1));
        minimumMargin = bound(minimumMargin, 0, collateralValue - 1);
        minimumMargin = bound(minimumMargin, 0, type(uint96).max);
        openDebt = bound(openDebt, 0, collateralValue - minimumMargin - 1);

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), openDebt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralValue);

        assertEq(collateralValue - openDebt - minimumMargin, accountExtension.getFreeMargin());
    }

    function testFuzz_Success_getFreeMargin_CreditorIsSet_ZeroFreeMargin(
        uint256 openDebt,
        uint256 minimumMargin,
        uint112 collateralValue
    ) public {
        // No overflow of Used Margin.
        minimumMargin = bound(minimumMargin, 0, type(uint256).max - openDebt);
        minimumMargin = bound(minimumMargin, 0, type(uint96).max);
        uint256 usedMargin = openDebt + minimumMargin;

        // Zero free margin -> "collateralValue" smaller or equal as "usedMargin".
        collateralValue = uint112(bound(collateralValue, 0, usedMargin));
        // "exposure" is strictly smaller than "maxExposure" -> collateralValue < type(uint128).max.
        collateralValue = uint112(bound(collateralValue, 0, type(uint112).max - 1));

        // Set minimumMargin
        accountExtension.setMinimumMargin(uint96(minimumMargin));

        // Mock initial debt.
        creditorStable1.setOpenPosition(address(accountExtension), openDebt);

        // Set Liquidation Value of assets (Liquidation value of token1 is 1:1 the amount of token1 tokens).
        depositErc20InAccount(accountExtension, mockERC20.stable1, collateralValue);

        assertEq(0, accountExtension.getFreeMargin());
    }
}
