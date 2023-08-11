/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import { Test } from "../../lib/forge-std/src/Test.sol";
import { Users, MockOracles, MockERC20, MockERC721, Rates } from "./utils/Types.sol";
import { Factory } from "../Factory.sol";
import { AccountV1 } from "../AccountV1.sol";
import { AccountV2 } from "../mockups/AccountV2.sol";
import { MainRegistryExtension, AccountExtension } from "./utils/Extensions.sol";
import { TrustedCreditorMock } from "../mockups/TrustedCreditorMock.sol";
import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";
import { Errors } from "./utils/Errors.sol";
import { ERC20Mock } from "../mockups/ERC20SolmateMock.sol";
import { ERC721Mock } from "../mockups/ERC721SolmateMock.sol";
import { ERC1155Mock } from "../mockups/ERC1155SolmateMock.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Global_Test is Test, Events, Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;
    address internal deployedAccountInputs0;
    // This will be the base currency set for the instance of "trustedCreditorWithParams"
    address internal initBaseCurrency;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Factory internal factory;
    MainRegistryExtension internal mainRegistryExtension;
    AccountV1 internal account;
    AccountV2 internal accountV2;
    AccountExtension internal accountExtension;
    TrustedCreditorMock internal trustedCreditorWithParamsInit;
    TrustedCreditorMock internal defaultTrustedCreditor;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        // Create users for testing
        users = Users({
            creatorAddress: createUser("creatorAddress"),
            tokenCreatorAddress: createUser("creatorAddress"),
            oracleOwner: createUser("oracleOwner"),
            unprivilegedAddress: createUser("unprivilegedAddress"),
            accountOwner: createUser("accountOwner"),
            liquidityProvider: createUser("liquidityProvider"),
            defaultCreatorAddress: createUser("defaultCreatorAddress"),
            defaultTransmitter: createUser("defaultTransmitter")
        });

        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        factory = new Factory();
        mainRegistryExtension = new MainRegistryExtension(address(factory));
        account = new AccountV1();
        accountV2 = new AccountV2();
        accountExtension = new AccountExtension(address(mainRegistryExtension));
        factory.setNewAccountInfo(address(mainRegistryExtension), address(account), Constants.upgradeProof1To2, "");
        trustedCreditorWithParamsInit = new TrustedCreditorMock();
        defaultTrustedCreditor = new TrustedCreditorMock();
        vm.stopPrank();

        // Label the base test contracts.
        vm.label({ account: address(factory), newLabel: "Factory" });
        vm.label({ account: address(mainRegistryExtension), newLabel: "Main Registry Extension" });
        vm.label({ account: address(account), newLabel: "Account" });
        vm.label({ account: address(accountV2), newLabel: "AccountV2" });
        vm.label({ account: address(defaultTrustedCreditor), newLabel: "Trusted Creditor Mock Not Initialized" });
        vm.label({ account: address(trustedCreditorWithParamsInit), newLabel: "Trusted Creditor Mock Initialized" });

        // Initialize the default liquidation cost and liquidator of trusted creditor
        // The base currency on initialization will depend on the type of test and set at a lower level
        trustedCreditorWithParamsInit.setFixedLiquidationCost(Constants.initLiquidationCost);
        trustedCreditorWithParamsInit.setLiquidator(Constants.initLiquidator);

        // Deploy an initial Account with all inputs to zero
        vm.startPrank(users.accountOwner);
        deployedAccountInputs0 = factory.createAccount(0, 0, address(0), address(0));
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
