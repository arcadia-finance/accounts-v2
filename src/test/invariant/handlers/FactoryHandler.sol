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
import "../../utils/Constants.sol";

contract FactoryHandler is BaseHandler {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Factory internal factory;
    MainRegistryExtension internal mainRegistryExtension;
    Vault internal vault;
    Vault internal vaultV2;

    // Track number of calls to functions
    uint256 public callsToCreateVault;
    uint256 public callsToSetNewVaultInfo;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/
    constructor(Factory factory_, MainRegistryExtension mainRegistryExtension_, Vault vault_, Vault vaultV2_) {
        factory = factory_;
        mainRegistryExtension = mainRegistryExtension_;
        vault = vault_;
        vaultV2 = vaultV2_;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/
    function createVault(uint256 salt, address baseCurrency) public {
        address creditor = address(0);
        uint16 vaultVersion = 0;
        factory.createVault(salt, vaultVersion, baseCurrency, creditor);
        callsToCreateVault++;
    }

    function setNewVaultInfo() public {
        callsToSetNewVaultInfo++;

        // Objective is to only activate a V2 once
        if (callsToSetNewVaultInfo == 3) {
            vm.prank(factory.owner());
            factory.setNewVaultInfo(address(mainRegistryExtension), address(vaultV2), Constants.upgradeProof1To2, "");
        }
    }
}
