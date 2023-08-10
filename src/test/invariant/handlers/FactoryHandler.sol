/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { BaseHandler } from "./BaseHandler.sol";
import { AccountV1 } from "../../../AccountV1.sol";
import { AccountV2 } from "../../../mockups/AccountV2.sol";
import { Factory } from "../../../Factory.sol";
import { MainRegistryExtension } from "../../utils/Extensions.sol";
import { TrustedCreditorMock } from "../../../mockups/TrustedCreditorMock.sol";
import "../../utils/Constants.sol";

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
    MainRegistryExtension internal mainRegistryExtension;
    AccountV1 internal account;
    AccountV2 internal accountV2;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/
    // Todo: Why do I have to add "memory" to the 2 account instances in the input
    constructor(Factory factory_, MainRegistryExtension mainRegistryExtension_, AccountV1 account_, AccountV2 accountV2_) {
        factory = factory_;
        mainRegistryExtension = mainRegistryExtension_;
        account = account_;
        accountV2 = accountV2_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    function createAccount(uint256 salt, address baseCurrency) public {
        address creditor = address(0);
        uint16 accountVersion = 0;
        factory.createAccount(salt, accountVersion, baseCurrency, creditor);
    }

    function setNewAccountInfo() public {
        callsToSetNewAccountInfo++;

        // Objective is to only activate a V2 once
        if (callsToSetNewAccountInfo == 3) {
            vm.prank(factory.owner());
            factory.setNewAccountInfo(
                address(mainRegistryExtension), address(accountV2), Constants.upgradeProof1To2, ""
            );
        }
    }
}
