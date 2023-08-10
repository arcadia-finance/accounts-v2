/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../Base_IntegrationAndUnit.t.sol";
import { AccountV1 } from "../../AccountV1.sol";
import "../utils/Constants.sol";

contract Account_Integration_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                          ACCOUNT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function test_openTrustedMarginAccount() public {
        // Assert no creditor has been set on deployment
        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(0));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), false);
        // Assert no liquidator, baseCurrency and liquidation costs have been defined on deployment
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), address(0));
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), 0);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(0));

        // Open a margin account
        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));
        vm.stopPrank();

        // Assert a creditor has been set and other variables updated
        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), true);
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), Constants.initLiquidator);
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), initBaseCurrency);
    }

    function testRevert_openTrustedMarginAccount_NotOwner() public {
        // Should revert if not called by the owner
        vm.expectRevert("V: Only Owner");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));
    }

    function testRevert_openTrustedMarginAccount_AlreadySet() public {
        // Open a margin account => will set a trusted creditor
        vm.startPrank(users.accountOwner);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));

        // Should revert if a trusted creditor is already set
        vm.expectRevert("V_OTMA: ALREADY SET");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));
    }

    function testRevert_openTrustedMarginAccount_InvalidAccountVersion() public {
        // set a different Account version on the trusted creditor
        defaultTrustedCreditor.setCallResult(false);
        vm.startPrank(users.accountOwner);
        vm.expectRevert("V_OTMA: Invalid Version");
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount((address(defaultTrustedCreditor)));
        vm.stopPrank();
    }

    function testFuzz_openTrustedMarginAccount_DifferentBaseCurrency(address liquidator, uint96 fixedLiquidationCost)
        public
    {
        // Confirm initial base currency is not set for the Account
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(0));

        // Update base currency of the trusted creditor to TOKEN1
        defaultTrustedCreditor.setBaseCurrency(address(mockERC20.token1));
        // Update liquidation costs in trusted creditor
        defaultTrustedCreditor.setFixedLiquidationCost(fixedLiquidationCost);
        // Update liquidator in trusted creditor
        defaultTrustedCreditor.setLiquidator(liquidator);

        vm.startPrank(users.accountOwner);
        vm.expectEmit();
        emit BaseCurrencySet(address(mockERC20.token1));
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(defaultTrustedCreditor), liquidator);
        AccountV1(deployedAccountInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));
        vm.stopPrank();

        assertEq(AccountV1(deployedAccountInputs0).trustedCreditor(), address(defaultTrustedCreditor));
        assertEq(AccountV1(deployedAccountInputs0).isTrustedCreditorSet(), true);
        assertEq(AccountV1(deployedAccountInputs0).liquidator(), liquidator);
        assertEq(AccountV1(deployedAccountInputs0).baseCurrency(), address(mockERC20.token1));
        assertEq(AccountV1(deployedAccountInputs0).fixedLiquidationCost(), fixedLiquidationCost);
    }

    function test_openTrustedMarginAccount_SameBaseCurrency() public {
        // Deploy a Account with baseCurrency set to STABLE1
        address deployedAccount = factory.createAccount(1111, 0, address(mockERC20.stable1), address(0));
        assertEq(AccountV1(deployedAccount).baseCurrency(), address(mockERC20.stable1));
        assertEq(trustedCreditorWithParamsInit.baseCurrency(), address(mockERC20.stable1));

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        AccountV1(deployedAccount).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));

        assertEq(AccountV1(deployedAccount).liquidator(), Constants.initLiquidator);
        assertEq(AccountV1(deployedAccount).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(AccountV1(deployedAccount).baseCurrency(), address(mockERC20.stable1));
        assertEq(AccountV1(deployedAccount).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertTrue(AccountV1(deployedAccount).isTrustedCreditorSet());
    }

    function testRevert_initialize_AlreadyInitialized() public {
        vm.expectRevert("V_I: Already initialized!");
        account.initialize(users.accountOwner, address(mainRegistryExtension), 1, address(0), address(0));
    }

    function testRevert_initialize_InvalidVersion() public {
        accountExtension.setAccountVersion(0);
        accountExtension.setOwner(address(0));

        vm.expectRevert("V_I: Invalid Account version");
        accountExtension.initialize(users.accountOwner, address(mainRegistryExtension), 0, address(0), address(0));
    }

    function test_initialize(address owner_, uint16 accountVersion_) public {
        vm.assume(accountVersion_ > 0);

        accountExtension.setAccountVersion(0);
        accountExtension.setOwner(address(0));

        vm.expectEmit(true, true, true, true);
        emit BaseCurrencySet(address(0));
        accountExtension.initialize(owner_, address(mainRegistryExtension), accountVersion_, address(0), address(0));

        assertEq(accountExtension.owner(), owner_);
        assertEq(accountExtension.registry(), address(mainRegistryExtension));
        assertEq(accountExtension.accountVersion(), accountVersion_);
        assertEq(accountExtension.baseCurrency(), address(0));
    }
}
