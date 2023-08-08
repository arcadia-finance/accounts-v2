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

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override {
        Base_Invariant_Test.setUp();
        factoryHandler = new FactoryHandler(factory, mainRegistryExtension, vault);
        targetContract(address(factoryHandler));
        initialVaultDeployed = factory.createVault(0, 0, address(0), address(0));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/
    function invariant_latestVaultVersion() public {
        uint256 numberOfVaults = factoryHandler.numberOfCallsToCreateVault();
        address latestDeployedVault = factory.allVaults(numberOfVaults);
        uint16 latestDeployedVaultVersion = Vault(latestDeployedVault).vaultVersion();
        assertGe(factory.latestVaultVersion(), latestDeployedVaultVersion);
    }
}
