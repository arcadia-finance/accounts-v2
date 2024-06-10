/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Invariant_Test } from "./Invariant.t.sol";

import { AccountV1 } from "../../src/accounts/AccountV1.sol";
import { AccountV2 } from "../utils/mocks/accounts/AccountV2.sol";
import { Factory } from "../../src/Factory.sol";
import { FactoryHandler } from "./handlers/FactoryHandler.sol";

/// @dev Invariant tests for { Factory }.
contract Factory_Invariant_Test is Invariant_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                      VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountV2 internal accountV2Logic;
    FactoryHandler internal factoryHandler;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/
    function setUp() public virtual override {
        Invariant_Test.setUp();

        vm.prank(users.owner);
        accountV2Logic = new AccountV2(address(factory));

        factoryHandler = new FactoryHandler(factory, registry, accountV1Logic, accountV2Logic);
        // We only want to target function calls inside the FactoryHandler contract
        targetContract(address(factoryHandler));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     INVARIANTS
    //////////////////////////////////////////////////////////////////////////*/
    function invariant_latestAccountVersion() public {
        uint256 numberOfAccounts = factory.allAccountsLength();
        address latestDeployedAccount = factory.allAccounts(numberOfAccounts - 1);
        uint256 latestDeployedAccountVersion = AccountV1(latestDeployedAccount).ACCOUNT_VERSION();

        // Assert that the Account version of latest Account deployed with input
        // accountVersion = 0 is always <= latest Account version in factory
        assertGe(factory.latestAccountVersion(), latestDeployedAccountVersion);
    }
}
