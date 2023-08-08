/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_Invariant_Test } from "./Base_Invariant.t.sol";
import { FactoryHandler } from "./handlers/FactoryHandler.sol";
import { Factory } from "../../Factory.sol";
import { Vault } from "../../Vault.sol";

contract Factory_Invariant_Test is Base_Invariant_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    address internal initialVaultDeployed;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    FactoryHandler internal factoryHandler;
    Vault internal vaultV2;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        Base_Invariant_Test.setUp();
        vaultV2 = new Vault();
        factoryHandler = new FactoryHandler(factory, mainRegistryExtension, vault, vaultV2);
        targetContract(address(factoryHandler));
        initialVaultDeployed = factory.createVault(0, 0, address(0), address(0));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/
    function invariant_latestVaultVersion() public {
        uint256 numberOfVaults = factory.allVaultsLength();
        address latestDeployedVault = factory.allVaults(numberOfVaults - 1);
        uint16 latestDeployedVaultVersion = Vault(latestDeployedVault).vaultVersion();

        // Assert that the vault version of latest vault deployed with input
        // vaultVersion = 0 is always <= latest vault version in factory
        assertGe(factory.latestVaultVersion(), latestDeployedVaultVersion);
    }
}
