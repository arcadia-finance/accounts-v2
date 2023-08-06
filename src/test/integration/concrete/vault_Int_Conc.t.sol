/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../../Base_IntegrationAndUnit.t.sol";
import { IVault } from "../../utils/Interfaces.sol";

contract Factory_Int_Fuzz_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    address internal deployedVaultInputs0;
    address internal mockLiquidator = address(666);
    address internal initBaseCurrency = address(mockERC20.stable1);
    uint256 internal initLiquidationCosts = 100;

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
        trustedCreditor.setBaseCurrency(initBaseCurrency);
        trustedCreditor.setLiquidator(mockLiquidator);
        trustedCreditor.setFixedLiquidationCost(initLiquidationCosts);
    }

    /* ///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function test_openTrustedMarginAccount() public {
        // Assert no creditor has been set on deployment
        assertEq(IVault(deployedVaultInputs0).trustedCreditor(), address(0));
        assertEq(IVault(deployedVaultInputs0).isTrustedCreditorSet(), false);

        // Open a margin account
        vm.startPrank(users.vaultOwner);
        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditor), mockLiquidator);
        IVault(deployedVaultInputs0).openTrustedMarginAccount(address(trustedCreditor));
        vm.stopPrank();

        // Assert a creditor has been set and other variables updated
        assertEq(IVault(deployedVaultInputs0).trustedCreditor(), address(trustedCreditor));
        assertEq(IVault(deployedVaultInputs0).isTrustedCreditorSet(), true);
        assertEq(IVault(deployedVaultInputs0).liquidator(), mockLiquidator);
        assertEq(IVault(deployedVaultInputs0).fixedLiquidationCost(), initLiquidationCosts);
        assertEq(IVault(deployedVaultInputs0).baseCurrency(), initBaseCurrency);
    }
}
