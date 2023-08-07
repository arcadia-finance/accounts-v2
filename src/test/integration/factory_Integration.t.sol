/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../Base_IntegrationAndUnit.t.sol";
import { Vault } from "../../Vault.sol";

contract Factory_Integration_Test is Base_IntegrationAndUnit_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    address internal initLiquidator;
    address internal initBaseCurrency;
    uint96 internal initLiquidationCost;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();

        // Set variables
        initLiquidator = address(666);
        initBaseCurrency = address(mockERC20.stable1);
        initLiquidationCost = 100;

        // Initialize storage variables for the trusted creditor mock contract
        trustedCreditor.setBaseCurrency(address(mockERC20.stable1));
        trustedCreditor.setLiquidator(initLiquidator);
        trustedCreditor.setFixedLiquidationCost(initLiquidationCost);
    }

    /* ///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testFuzz_createVault_DeployVaultWithNoCreditor(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit();
        emit Transfer(address(0), address(this), 1);
        vm.expectEmit(false, true, true, true);
        emit VaultUpgraded(address(0), 0, 1);

        // Here we create a vault with no specific trusted creditor
        address actualDeployed = factory.createVault(salt, 0, address(0), address(0));

        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
        assertEq(Vault(actualDeployed).trustedCreditor(), address(0));
        assertEq(Vault(actualDeployed).isTrustedCreditorSet(), false);
        assertEq(Vault(actualDeployed).owner(), address(this));
    }

    function testFuzz_createVault_DeployVaultWithCreditor(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditor), initLiquidator);
        vm.expectEmit();
        emit Transfer(address(0), address(this), 1);
        vm.expectEmit(false, true, true, true);
        emit VaultUpgraded(address(0), 0, 1);

        // Here we create a vault by specifying the trusted creditor address
        address actualDeployed = factory.createVault(salt, 0, address(0), address(trustedCreditor));

        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
        assertEq(Vault(actualDeployed).trustedCreditor(), address(trustedCreditor));
        assertEq(Vault(actualDeployed).isTrustedCreditorSet(), true);
    }
}
