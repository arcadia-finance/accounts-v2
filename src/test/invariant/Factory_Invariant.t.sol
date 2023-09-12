/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Base_Invariant_Test } from "./Base_Invariant.t.sol";
import { FactoryHandler } from "./handlers/FactoryHandler.sol";
import { Factory } from "../../Factory.sol";
import { AccountV1 } from "../../AccountV1.sol";

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
        factoryHandler = new FactoryHandler(factory, mainRegistryExtension, accountV1Logic, accountV2Logic);
        // We only want to target function calls inside the FactoryHandler contract
        targetContract(address(factoryHandler));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/
    function invariant_latestAccountVersion() public {
        uint256 numberOfAccounts = factory.allAccountsLength();
        address latestDeployedAccount = factory.allAccounts(numberOfAccounts - 1);
        uint16 latestDeployedAccountVersion = AccountV1(latestDeployedAccount).ACCOUNT_VERSION();

        // Assert that the Account version of latest Account deployed with input
        // accountVersion = 0 is always <= latest Account version in factory
        assertGe(factory.latestAccountVersion(), latestDeployedAccountVersion);
    }
}
