/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { BaseHandler } from "./BaseHandler.sol";
import { AccountV3 } from "../../../src/accounts/AccountV3.sol";
import { AccountLogicMock } from "../../utils/mocks/accounts/AccountLogicMock.sol";
import { Factory } from "../../../src/Factory.sol";
import { RegistryL2Extension } from "../../utils/extensions/RegistryL2Extension.sol";
import { Constants } from "../../utils/Constants.sol";

/// @dev This contract and not { Factory } is exposed to Foundry for invariant testing. The point is
/// to bound and restrict the inputs that get passed to the real-world contract to avoid getting reverts.
contract FactoryHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    // Track number of calls to functions
    uint256 public callsToSetNewAccountInfo;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Factory internal factory;
    RegistryL2Extension internal registry;
    AccountV3 internal account;
    AccountLogicMock internal accountV2;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/
    constructor(
        Factory factory_,
        RegistryL2Extension registryExtension_,
        AccountV3 account_,
        AccountLogicMock accountV2_
    ) {
        factory = factory_;
        registry = registryExtension_;
        account = account_;
        accountV2 = accountV2_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    function createAccount(uint32 salt) public {
        address creditor = address(0);
        uint16 accountVersion = 0;
        factory.createAccount(salt, accountVersion, creditor);
    }

    function setNewAccountInfo() public {
        callsToSetNewAccountInfo++;

        // Objective is to only activate a V2 once
        if (callsToSetNewAccountInfo == 3) {
            vm.prank(factory.owner());
            factory.setNewAccountInfo(address(registry), address(accountV2), Constants.ROOT, "");
        }
    }
}
