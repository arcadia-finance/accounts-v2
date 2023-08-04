/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_IntegrationAndUnit_Test } from "../../Base_IntegrationAndUnit.t.sol";

abstract contract Factory_Int_Fuzz_Test is Base_IntegrationAndUnit_Test {
    function setUp() public virtual override(Base_IntegrationAndUnit_Test) {
        Base_IntegrationAndUnit_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    function testSuccess_createVault_DeployVaultContractMappings(uint256 salt) public {
        uint256 amountBefore = factory.allVaultsLength();

        vm.expectEmit(true, true, true, false);
        emit Transfer(address(0), address(this), 1);
        vm.expectEmit(true, false, true, false);
        emit VaultUpgraded(address(0), 0, 1);
        address actualDeployed = factory.createVault(salt, 0, address(0), address(0));
        assertEq(amountBefore + 1, factory.allVaultsLength());
        assertEq(actualDeployed, factory.allVaults(factory.allVaultsLength() - 1));
        assertEq(factory.vaultIndex(actualDeployed), (factory.allVaultsLength()));
    }
}
