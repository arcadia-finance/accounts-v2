/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { Users, MockOracles, MockERC20, MockERC721, Rates } from "./utils/Types.sol";
import { Factory } from "../Factory.sol";
import { Vault } from "../Vault.sol";
import { MainRegistryExtension } from "./utils/Extensions.sol";
import { TrustedCreditorMock } from "../mockups/TrustedCreditorMock.sol";
import "./utils/Constants.sol";
import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ERC721SolmateMock.sol";
import "../mockups/ERC1155SolmateMock.sol";
import "./utils/Events.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Global_Test is Test, Events {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    address internal deployedVaultInputs0;
    // This will be the base currency set for the instance of "trustedCreditorWithParams"
    address internal initBaseCurrency;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Factory internal factory;
    MainRegistryExtension internal mainRegistryExtension;
    Vault internal vault;
    Vault internal vaultV2;
    TrustedCreditorMock internal trustedCreditorWithParamsInit;
    TrustedCreditorMock internal defaultTrustedCreditor;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        factory = new Factory();
        mainRegistryExtension = new MainRegistryExtension(address(factory));
        vault = new Vault();
        vaultV2 = new Vault();
        factory.setNewVaultInfo(address(mainRegistryExtension), address(vault), Constants.upgradeProof1To2, "");
        trustedCreditorWithParamsInit = new TrustedCreditorMock();
        defaultTrustedCreditor = new TrustedCreditorMock();
        vm.stopPrank();

        // Label the base test contracts.
        vm.label({ account: address(factory), newLabel: "Factory" });
        vm.label({ account: address(mainRegistryExtension), newLabel: "Main Registry Extension" });
        vm.label({ account: address(vault), newLabel: "Vault" });
        vm.label({ account: address(defaultTrustedCreditor), newLabel: "Trusted Creditor Mock Not Initialized" });
        vm.label({ account: address(trustedCreditorWithParamsInit), newLabel: "Trusted Creditor Mock Initialized" });


        // Create users for testing
        vm.startPrank(users.tokenCreatorAddress);
        users = Users({
            creatorAddress: createUser("creatorAddress"),
            tokenCreatorAddress: createUser("creatorAddress"),
            oracleOwner: createUser("oracleOwner"),
            unprivilegedAddress: createUser("unprivilegedAddress"),
            vaultOwner: createUser("vaultOwner"),
            liquidityProvider: createUser("liquidityProvider"),
            defaultCreatorAddress: createUser("defaultCreatorAddress"),
            defaultTransmitter: createUser("defaultTransmitter")
        });
        vm.stopPrank();

        // Initialize the default base currency and liquidator of trusted creditor
        // The base currency on initialization will depend on the type of test
        trustedCreditorWithParamsInit.setFixedLiquidationCost(Constants.initLiquidationCost);
        trustedCreditorWithParamsInit.setLiquidator(Constants.initLiquidator);

        // Deploy an initial vault with all inputs to zero
        vm.startPrank(users.vaultOwner);
        deployedVaultInputs0 = factory.createVault(0, 0, address(0), address(0));
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
