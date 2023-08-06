/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../../Base_IntegrationAndUnit.t.sol";
import { IVault } from "../../utils/Interfaces.sol";
import { Factory } from "../../../Factory.sol";

contract Factory_Int_Fuzz_Test is Base_IntegrationAndUnit_Test {
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

    function testFuzz_createVault_DeployVaultContractMappings(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit();
        emit Transfer(address(0), address(this), 1);
        vm.expectEmit(false, true, true, true);
        emit VaultUpgraded(address(0), 0, 1);
        address actualDeployed = factory.createVault(salt, 0, address(0), address(0));
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
    }

    function testFuzz_createVault_DeployVaultContractMappingsWithCreditor(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit();
        emit TrustedMarginAccountChanged(address(trustedCreditor), address(0));
        vm.expectEmit();
        emit Transfer(address(0), address(this), 1);
        vm.expectEmit(false, true, true, true);
        emit VaultUpgraded(address(0), 0, 1);

        address actualDeployed = factory.createVault(salt, 0, address(0), address(trustedCreditor));
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
        assertEq(IVault(actualDeployed).trustedCreditor(), address(trustedCreditor));
        assertEq(IVault(actualDeployed).isTrustedCreditorSet(), true);
    }
}
