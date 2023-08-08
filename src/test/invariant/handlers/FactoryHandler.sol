/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { BaseHandler } from "./BaseHandler.sol";
import { Vault } from "../../../Vault.sol";
import { Factory } from "../../../Factory.sol";
import { MainRegistryExtension } from "../../utils/Extensions.sol";
import { TrustedCreditorMock } from "../../../mockups/TrustedCreditorMock.sol";

contract FactoryHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Factory internal factory;
    MainRegistryExtension internal mainRegistryExtension;
    Vault internal vault;

    uint256 public numberOfCallsToCreateVault;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/
    constructor(Factory factory_, MainRegistryExtension mainRegistryExtension_, Vault vault_) {
        factory = factory_;
        mainRegistryExtension = mainRegistryExtension_;
        vault = vault_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    function createVault(uint256 salt, address baseCurrency) public {
        address creditor = address(0);
        uint16 vaultVersion = 0;
        factory.createVault(salt, vaultVersion, baseCurrency, creditor);
        numberOfCallsToCreateVault++;
    }
}
