/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AccountV1_Fuzz_Test, AccountErrors } from "./_AccountV1.fuzz.t.sol";

import { AccountExtension, AccountV1 } from "../../../utils/Extensions.sol";
import { Constants } from "../../../utils/Constants.sol";

/**
 * @notice Fuzz tests for the function "openMarginAccount" of contract "AccountV1".
 */
contract OpenMarginAccount_AccountV1_Fuzz_Test is AccountV1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        AccountV1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_openMarginAccount_NotOwner() public {
        // Should revert if not called by the owner
        vm.expectRevert(AccountErrors.OnlyOwner.selector);
        proxyAccount.openMarginAccount(address(creditorStable1));
    }

    function testFuzz_Revert_openMarginAccount_AlreadySet() public {
        // Open a margin account => will set a creditor
        vm.startPrank(users.accountOwner);
        proxyAccount.openMarginAccount(address(creditorStable1));

        // Should revert if a creditor is already set
        vm.expectRevert(AccountErrors.CreditorAlreadySet.selector);
        proxyAccount.openMarginAccount(address(creditorStable1));
    }

    function testFuzz_Revert_openMarginAccount_InvalidAccountVersion() public {
        // set a different Account version on the creditor
        creditorStable1.setCallResult(false);
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.InvalidAccountVersion.selector);
        proxyAccount.openMarginAccount((address(creditorStable1)));
        vm.stopPrank();
    }

    function testFuzz_Success_openMarginAccount() public {
        // Assert no creditor has been set on deployment
        assertEq(proxyAccount.creditor(), address(0));
        assertEq(proxyAccount.isCreditorSet(), false);
        // Assert no liquidator, baseCurrency and liquidation costs have been defined on deployment
        assertEq(proxyAccount.liquidator(), address(0));
        assertEq(proxyAccount.fixedLiquidationCost(), 0);
        assertEq(proxyAccount.baseCurrency(), address(0));

        // Open a margin account
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit MarginAccountChanged(address(creditorStable1), Constants.initLiquidator);
        proxyAccount.openMarginAccount(address(creditorStable1));
        vm.stopPrank();

        // Assert a creditor has been set and other variables updated
        assertEq(proxyAccount.creditor(), address(creditorStable1));
        assertEq(proxyAccount.isCreditorSet(), true);
        assertEq(proxyAccount.liquidator(), Constants.initLiquidator);
        assertEq(proxyAccount.fixedLiquidationCost(), Constants.initLiquidationCost);
        assertEq(proxyAccount.baseCurrency(), address(mockERC20.stable1));
    }

    function testFuzz_Success_openMarginAccount_DifferentBaseCurrency(address liquidator, uint96 fixedLiquidationCost)
        public
    {
        // Confirm initial base currency is not set for the Account
        assertEq(proxyAccount.baseCurrency(), address(0));

        // Update base currency of the creditor to TOKEN1
        creditorStable1.setBaseCurrency(address(mockERC20.token1));
        // Update liquidation costs in creditor
        creditorStable1.setFixedLiquidationCost(fixedLiquidationCost);
        // Update liquidator in creditor
        creditorStable1.setLiquidator(liquidator);

        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit BaseCurrencySet(address(mockERC20.token1));
        vm.expectEmit();
        emit MarginAccountChanged(address(creditorStable1), liquidator);
        proxyAccount.openMarginAccount(address(creditorStable1));
        vm.stopPrank();

        assertEq(proxyAccount.creditor(), address(creditorStable1));
        assertEq(proxyAccount.isCreditorSet(), true);
        assertEq(proxyAccount.liquidator(), liquidator);
        assertEq(proxyAccount.baseCurrency(), address(mockERC20.token1));
        assertEq(proxyAccount.fixedLiquidationCost(), fixedLiquidationCost);
    }

    function testFuzz_Success_openMarginAccount_SameBaseCurrency() public {
        // Deploy an Account with baseCurrency set to STABLE1
        address deployedAccount = factory.createAccount(1111, 0, address(mockERC20.stable1), address(0));
        assertEq(AccountV1(deployedAccount).baseCurrency(), address(mockERC20.stable1));
        assertEq(creditorStable1.baseCurrency(), address(mockERC20.stable1));

        vm.expectEmit();
        emit MarginAccountChanged(address(creditorStable1), Constants.initLiquidator);
        AccountV1(deployedAccount).openMarginAccount(address(creditorStable1));

        assertEq(AccountV1(deployedAccount).liquidator(), Constants.initLiquidator);
        assertEq(AccountV1(deployedAccount).creditor(), address(creditorStable1));
        assertEq(AccountV1(deployedAccount).baseCurrency(), address(mockERC20.stable1));
        assertEq(AccountV1(deployedAccount).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertTrue(AccountV1(deployedAccount).isCreditorSet());
    }
}
