/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AccountsGuardExtension } from "./utils/extensions/AccountsGuardExtension.sol";
import { AccountV3 } from "../src/accounts/AccountV3.sol";
import { ChainlinkOMExtension } from "./utils/extensions/ChainlinkOMExtension.sol";
import { ERC20PrimaryAMExtension } from "./utils/extensions/ERC20PrimaryAMExtension.sol";
import { ERC721TokenReceiver } from "../lib/solmate/src/tokens/ERC721.sol";
import { FactoryExtension } from "./utils/extensions/FactoryExtension.sol";
import { RegistryL2Extension } from "./utils/extensions/RegistryL2Extension.sol";
import { SequencerUptimeOracle } from "./utils/mocks/oracles/SequencerUptimeOracle.sol";
import { Test } from "../lib/forge-std/src/Test.sol";
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

    AccountsGuardExtension internal accountsGuard;
    AccountV3 internal account;
    AccountV3 internal accountLogic;
    ChainlinkOMExtension internal chainlinkOM;
    ERC20PrimaryAMExtension internal erc20AM;
    FactoryExtension internal factory;
    RegistryL2Extension internal registry;
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
        vm.assume(to != 0x4200000000000000000000000000000000000006);
        if (to.code.length != 0) {
            try ERC721TokenReceiver(to).onERC721Received(to, address(0), 0, "") returns (bytes4 response) {
                vm.assume(response == ERC721TokenReceiver.onERC721Received.selector);
            } catch {
                vm.assume(false);
            }
        }
        _;
    }

    function isPrecompile(address addr) internal pure returns (bool) {
        return isPrecompile(addr, 1);
    }

    function isPrecompile(address addr, uint256 chainId) internal pure returns (bool) {
        // Note: For some chains like Optimism these are technically predeploys (i.e. bytecode placed at a specific
        // address), but the same rationale for excluding them applies so we include those too.

        // These should be present on all EVM-compatible chains.
        if (addr >= address(0x1) && addr <= address(0x9)) return true;

        // forgefmt: disable-start
        if (chainId == 10 || chainId == 420) {
            // https://github.com/ethereum-optimism/optimism/blob/eaa371a0184b56b7ca6d9eb9cb0a2b78b2ccd864/op-bindings/predeploys/addresses.go#L6-L21
            return (addr >= address(0x4200000000000000000000000000000000000000) && addr <= address(0x4200000000000000000000000000000000000800));
        } else if (chainId == 42161 || chainId == 421613) {
            // https://developer.arbitrum.io/useful-addresses#arbitrum-precompiles-l2-same-on-all-arb-chains
            return (addr >= address(0x0000000000000000000000000000000000000064) && addr <= address(0x0000000000000000000000000000000000000068));
        } else if (chainId == 43114 || chainId == 43113) {
            // https://github.com/ava-labs/subnet-evm/blob/47c03fd007ecaa6de2c52ea081596e0a88401f58/precompile/params.go#L18-L59
            return ((addr >= address(0x0100000000000000000000000000000000000000) && addr <= address(0x01000000000000000000000000000000000000ff))
            || (addr >= address(0x0200000000000000000000000000000000000000) && addr <= address(0x02000000000000000000000000000000000000FF))
            || (addr >= address(0x0300000000000000000000000000000000000000) && addr <= address(0x03000000000000000000000000000000000000Ff)));
        }
        // forgefmt: disable-end

        return false;
    }
}
