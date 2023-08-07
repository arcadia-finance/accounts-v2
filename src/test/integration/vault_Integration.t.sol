/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../Base_IntegrationAndUnit.t.sol";
import { Vault } from "../../Vault.sol";
import { TrustedCreditorMock } from "../../mockups/TrustedCreditorMock.sol";
import "../../../lib/forge-std/src/Test.sol";

contract Vault_Integration_Test is Base_IntegrationAndUnit_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    address internal deployedVaultInputs0;
    address internal initLiquidator = address(666);
    address internal initBaseCurrency = address(mockERC20.stable1);
    uint96 internal initLiquidationCosts = 100;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();

        // Deploy a Vault with all input params to 0
        vm.startPrank(users.vaultOwner);
        deployedVaultInputs0 = factory.createVault(0, 0, address(0), address(0));
        vm.stopPrank();

        // Initialize storage variables for the trusted creditor mock contract
        // todo : why does it not work without the interface here ??
        TrustedCreditorMock(address(trustedCreditor)).setBaseCurrency(address(mockERC20.stable1));
        emit log_named_address("trusted creditor base currency", trustedCreditor.baseCurrency());
        trustedCreditor.setLiquidator(initLiquidator);
        emit log_named_address("init liquidator base currency", trustedCreditor.liquidator());
        trustedCreditor.setFixedLiquidationCost(initLiquidationCosts);
        emit log_named_uint("init liquidaton costs", trustedCreditor.fixedLiquidationCost());
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
        emit TrustedMarginAccountChanged(address(trustedCreditor), initLiquidator);
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(trustedCreditor));
        vm.stopPrank();

        // Assert a creditor has been set and other variables updated
        assertEq(Vault(deployedVaultInputs0).trustedCreditor(), address(trustedCreditor));
        assertEq(Vault(deployedVaultInputs0).isTrustedCreditorSet(), true);
        assertEq(Vault(deployedVaultInputs0).liquidator(), initLiquidator);
        assertEq(Vault(deployedVaultInputs0).fixedLiquidationCost(), initLiquidationCosts);
        assertEq(Vault(deployedVaultInputs0).baseCurrency(), initBaseCurrency);
    }

    function test_RevertWhen_openTrustedMarginAccount_NotOwner() public {
        // Should revert if not called by the owner
        vm.expectRevert("V: Only Owner");
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(trustedCreditor));
    }

    function test_RevertWhen_openTrustedMarginAccount_AlreadySet() public {
        // Open a margin account (no creditor has been set yet)
        vm.startPrank(users.vaultOwner);
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(trustedCreditor));

        // Should revert if a trusted creditor is already set
        vm.expectRevert("V_OTMA: ALREADY SET");
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(trustedCreditor));
    }

    function test_RevertWhen_openTrustedMarginAccount_InvalidVaultVersion() public {
        // set a different vault version on the trusted creditor
        trustedCreditor.setCallResult(false);
        vm.startPrank(users.vaultOwner);
        vm.expectRevert("V_OTMA: Invalid Version");
        Vault(deployedVaultInputs0).openTrustedMarginAccount((address(trustedCreditor)));
        vm.stopPrank();
    }

    function testFuzz_openTrustedMarginAccount_DifferentBaseCurrency(address liquidator, uint96 fixedLiquidationCost)
        public
    {
        // Confirm initial base currency is not set for the vault
        assertEq(Vault(deployedVaultInputs0).baseCurrency(), address(0));

        // Update base currency of the trusted creditor to TOKEN1
        trustedCreditor.setBaseCurrency(address(mockERC20.token1));
        // Update liquidation costs in trusted creditor
        trustedCreditor.setFixedLiquidationCost(fixedLiquidationCost);
        // Update liquidator in trusted creditor
        trustedCreditor.setLiquidator(liquidator);

        vm.startPrank(users.vaultOwner);
        vm.expectEmit();
        emit BaseCurrencySet(address(mockERC20.token1));
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditor), liquidator);
        Vault(deployedVaultInputs0).openTrustedMarginAccount(address(trustedCreditor));
        vm.stopPrank();

        assertEq(Vault(deployedVaultInputs0).trustedCreditor(), address(trustedCreditor));
        assertEq(Vault(deployedVaultInputs0).isTrustedCreditorSet(), true);
        assertEq(Vault(deployedVaultInputs0).liquidator(), liquidator);
        assertEq(Vault(deployedVaultInputs0).baseCurrency(), address(mockERC20.token1));
        assertEq(Vault(deployedVaultInputs0).fixedLiquidationCost(), fixedLiquidationCost);
    }

    function test_openTrustedMarginAccount_SameBaseCurrency() public {
        // Deploy a vault with baseCurrency set to STABLE1
        address deployedVault = factory.createVault(1111, 0, address(mockERC20.stable1), address(0));
        assertEq(Vault(deployedVault).baseCurrency(), address(mockERC20.stable1));
        assertEq(trustedCreditor.baseCurrency(), address(mockERC20.stable1));

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditor), initLiquidator);
        Vault(deployedVault).openTrustedMarginAccount(address(trustedCreditor));

        assertEq(Vault(deployedVault).liquidator(), initLiquidator);
        assertEq(Vault(deployedVault).trustedCreditor(), address(trustedCreditor));
        assertEq(Vault(deployedVault).baseCurrency(), address(mockERC20.stable1));
        assertEq(Vault(deployedVault).fixedLiquidationCost(), initLiquidationCosts);
        assertTrue(Vault(deployedVault).isTrustedCreditorSet());
    }
}
