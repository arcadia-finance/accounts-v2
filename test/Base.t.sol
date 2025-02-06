/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Test } from "../lib/forge-std/src/Test.sol";

import { AccountV1 } from "../src/accounts/AccountV1.sol";
import { ChainlinkOMExtension } from "./utils/extensions/ChainlinkOMExtension.sol";
import { ERC20PrimaryAMExtension } from "./utils/extensions/ERC20PrimaryAMExtension.sol";
import { ERC721TokenReceiver } from "../lib/solmate/src/tokens/ERC721.sol";
import { Factory } from "../src/Factory.sol";
import { RegistryExtension } from "./utils/extensions/RegistryExtension.sol";
import { SequencerUptimeOracle } from "./utils/mocks/oracles/SequencerUptimeOracle.sol";
import { Users } from "./utils/Types.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                  CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // baseToQuoteAsset arrays
    bool[] internal BA_TO_QA_SINGLE = new bool[](1);
    bool[] internal BA_TO_QA_DOUBLE = new bool[](2);

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    AccountV1 internal account;
    AccountV1 internal accountV1Logic;
    ChainlinkOMExtension internal chainlinkOM;
    ERC20PrimaryAMExtension internal erc20AM;
    Factory internal factory;
    RegistryExtension internal registry;
    SequencerUptimeOracle internal sequencerUptimeOracle;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        BA_TO_QA_SINGLE[0] = true;
        BA_TO_QA_DOUBLE[0] = true;
        BA_TO_QA_DOUBLE[1] = true;
    }

    function setUp() public virtual {
        // Create users for testing
        users = Users({
            accountOwner: createUser("accountOwner"),
            guardian: createUser("guardian"),
            liquidityProvider: createUser("liquidityProvider"),
            oracleOwner: createUser("oracleOwner"),
            owner: createUser("owner"),
            riskManager: createUser("riskManager"),
            swapper: createUser("swapper"),
            tokenCreator: createUser("tokenCreator"),
            transmitter: createUser("transmitter"),
            treasury: createUser("treasury"),
            unprivilegedAddress: createUser("unprivilegedAddress")
        });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Generates a user, labels its address, and funds it with test assets.
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }

    modifier canReceiveERC721(address to) {
        vm.assume(to != address(0));
        if (to.code.length != 0) {
            try ERC721TokenReceiver(to).onERC721Received(to, address(0), 0, "") returns (bytes4 response) {
                vm.assume(response == ERC721TokenReceiver.onERC721Received.selector);
            } catch {
                vm.assume(false);
            }
        }
        _;
    }
}
