/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../Base_IntegrationAndUnit.t.sol";
import { Vault } from "../../Vault.sol";
import "../utils/Constants.sol";

contract Vault_Integration_Test is Base_IntegrationAndUnit_Test {
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
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function test_openTrustedMarginAccount() public {
        // Assert no creditor has been set on deployment
        assertEq(Vault(deployedVaultInputs0).trustedCreditor(), address(0));
        assertEq(Vault(deployedVaultInputs0).isTrustedCreditorSet(), false);
        // Assert no liquidator, baseCurrency and liquidation costs have been defined on deployment
        assertEq(Vault(deployedVaultInputs0).liquidator(), address(0));
        assertEq(Vault(deployedVaultInputs0).fixedLiquidationCost(), 0);
        assertEq(Vault(deployedVaultInputs0).baseCurrency(), address(0));

        // Open a margin account
        vm.startPrank(users.vaultOwner);
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));
        vm.stopPrank();

        // Assert a creditor has been set and other variables updated
        assertEq(Vault(deployedVaultInputs0).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(Vault(deployedVaultInputs0).isTrustedCreditorSet(), true);
        assertEq(Vault(deployedVaultInputs0).liquidator(), Constants.initLiquidator);
        assertEq(Vault(deployedVaultInputs0).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertEq(Vault(deployedVaultInputs0).baseCurrency(), initBaseCurrency);
    }

    function test_Revert_openTrustedMarginAccount_NotOwner() public {
        // Should revert if not called by the owner
        vm.expectRevert("V: Only Owner");
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));
    }

    function test_Revert_openTrustedMarginAccount_AlreadySet() public {
        // Open a margin account => will set a trusted creditor
        vm.startPrank(users.vaultOwner);
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));

        // Should revert if a trusted creditor is already set
        vm.expectRevert("V_OTMA: ALREADY SET");
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));
    }

    function test_Revert_openTrustedMarginAccount_InvalidVaultVersion() public {
        // set a different vault version on the trusted creditor
        defaultTrustedCreditor.setCallResult(false);
        vm.startPrank(users.vaultOwner);
        vm.expectRevert("V_OTMA: Invalid Version");
        Vault(deployedVaultInputs0).openTrustedMarginAccount((address(defaultTrustedCreditor)));
        vm.stopPrank();
    }

    function testFuzz_openTrustedMarginAccount_DifferentBaseCurrency(address liquidator, uint96 fixedLiquidationCost)
        public
    {
        // Confirm initial base currency is not set for the vault
        assertEq(Vault(deployedVaultInputs0).baseCurrency(), address(0));

        // Update base currency of the trusted creditor to TOKEN1
        defaultTrustedCreditor.setBaseCurrency(address(mockERC20.token1));
        // Update liquidation costs in trusted creditor
        defaultTrustedCreditor.setFixedLiquidationCost(fixedLiquidationCost);
        // Update liquidator in trusted creditor
        defaultTrustedCreditor.setLiquidator(liquidator);

        vm.startPrank(users.vaultOwner);
        vm.expectEmit();
        emit BaseCurrencySet(address(mockERC20.token1));
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(defaultTrustedCreditor), liquidator);
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(defaultTrustedCreditor));
        vm.stopPrank();

        assertEq(Vault(deployedVaultInputs0).trustedCreditor(), address(defaultTrustedCreditor));
        assertEq(Vault(deployedVaultInputs0).isTrustedCreditorSet(), true);
        assertEq(Vault(deployedVaultInputs0).liquidator(), liquidator);
        assertEq(Vault(deployedVaultInputs0).baseCurrency(), address(mockERC20.token1));
        assertEq(Vault(deployedVaultInputs0).fixedLiquidationCost(), fixedLiquidationCost);
    }

    function test_openTrustedMarginAccount_SameBaseCurrency() public {
        // Deploy a vault with baseCurrency set to STABLE1
        address deployedVault = factory.createVault(1111, 0, address(mockERC20.stable1), address(0));
        assertEq(Vault(deployedVault).baseCurrency(), address(mockERC20.stable1));
        assertEq(trustedCreditorWithParamsInit.baseCurrency(), address(mockERC20.stable1));

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        Vault(deployedVault).openTrustedMarginAccount(address(trustedCreditorWithParamsInit));

        assertEq(Vault(deployedVault).liquidator(), Constants.initLiquidator);
        assertEq(Vault(deployedVault).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(Vault(deployedVault).baseCurrency(), address(mockERC20.stable1));
        assertEq(Vault(deployedVault).fixedLiquidationCost(), Constants.initLiquidationCost);
        assertTrue(Vault(deployedVault).isTrustedCreditorSet());
    }
}
