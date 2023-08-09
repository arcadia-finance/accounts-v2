/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../Base_IntegrationAndUnit.t.sol";
import { Vault } from "../../Vault.sol";
import "../utils/Constants.sol";

contract Factory_Integration_Test is Base_IntegrationAndUnit_Test {
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

    function testFuzz_createVault_DeployVaultWithNoCreditor(uint256 salt) public {
        // We assume that salt > 0 as we already deployed a vault with all inputs to 0
        vm.assume(salt > 0);
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit();
        emit Transfer(address(0), address(this), amountBefore + 1);
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
        // We assume that salt > 0 as we already deployed a vault with all inputs to 0
        vm.assume(salt > 0);
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditorWithParamsInit), Constants.initLiquidator);
        vm.expectEmit();
        emit Transfer(address(0), address(this), amountBefore + 1);
        vm.expectEmit(false, true, true, true);
        emit VaultUpgraded(address(0), 0, 1);

        // Here we create a vault by specifying the trusted creditor address
        address actualDeployed = factory.createVault(salt, 0, address(0), address(trustedCreditorWithParamsInit));

        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
        assertEq(Vault(actualDeployed).trustedCreditor(), address(trustedCreditorWithParamsInit));
        assertEq(Vault(actualDeployed).isTrustedCreditorSet(), true);
    }
}
