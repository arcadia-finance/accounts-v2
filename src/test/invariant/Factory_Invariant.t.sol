/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Base_Invariant_Test } from "./Base_Invariant.t.sol";
import { FactoryHandler } from "./handlers/FactoryHandler.sol";
import { Factory } from "../../Factory.sol";
import { Vault } from "../../Vault.sol";

/// @dev Invariant tests for { Factory }.
contract Factory_Invariant_Test is Base_Invariant_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                      VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    FactoryHandler internal factoryHandler;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        Base_Invariant_Test.setUp();
        factoryHandler = new FactoryHandler(factory, mainRegistryExtension, vault, vaultV2);
        // We only want to target function calls inside the FactoryHandler contract
        targetContract(address(factoryHandler));
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
