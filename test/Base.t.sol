/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../lib/forge-std/src/Test.sol";

import { AccountV1 } from "../src/accounts/AccountV1.sol";
import { AccountV2 } from "./utils/mocks/accounts/AccountV2.sol";
import { AssetModule } from "../src/asset-modules/abstracts/AbstractAM.sol";
import { ChainlinkOMExtension } from "./utils/extensions/ChainlinkOMExtension.sol";
import { Constants } from "./utils/Constants.sol";
import { ERC20PrimaryAMExtension } from "./utils/extensions/ERC20PrimaryAMExtension.sol";
import { ERC721TokenReceiver } from "../lib/solmate/src/tokens/ERC721.sol";
import { Factory } from "../src/Factory.sol";
import { FloorERC721AMExtension } from "./utils/extensions/FloorERC721AMExtension.sol";
import { FloorERC1155AMExtension } from "./utils/extensions/FloorERC1155AMExtension.sol";
import { RegistryExtension } from "./utils/extensions/RegistryExtension.sol";
import { SequencerUptimeOracle } from "./utils/mocks/oracles/SequencerUptimeOracle.sol";
import { UniswapV3AMExtension } from "./utils/extensions/UniswapV3AMExtension.sol";
import { Users } from "./utils/Types.sol";
import { Utils } from "./utils/Utils.sol";

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
    AccountV2 internal accountV2Logic;
    ChainlinkOMExtension internal chainlinkOM;
    ERC20PrimaryAMExtension internal erc20AM;
    Factory internal factory;
    FloorERC721AMExtension internal floorERC721AM;
    FloorERC1155AMExtension internal floorERC1155AM;
    RegistryExtension internal registry;
    SequencerUptimeOracle internal sequencerUptimeOracle;
    UniswapV3AMExtension internal uniV3AM;

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

    function deployUniswapV3AM(address nonfungiblePositionManager_) internal {
        // Get the bytecode of the UniswapV3PoolExtension.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV3PoolExtension.sol"), args);
        bytes32 poolExtensionInitCodeHash = keccak256(bytecode);

        // Get the bytecode of UniswapV3AMExtension.
        args = abi.encode(address(registry), nonfungiblePositionManager_);
        bytecode = abi.encodePacked(vm.getCode("UniswapV3AMExtension.sol:UniswapV3AMExtension"), args);

        // Overwrite constant in bytecode of NonfungiblePositionManager.
        // -> Replace the code hash of UniswapV3Pool.sol with the code hash of UniswapV3PoolExtension.sol
        bytes32 POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytecode = Utils.veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);

        // Deploy UniswapV3PoolExtension with modified bytecode.
        vm.prank(users.owner);
        address uniV3AssetModule_ = Utils.deployBytecode(bytecode);
        uniV3AM = UniswapV3AMExtension(uniV3AssetModule_);

        vm.label({ account: address(uniV3AM), newLabel: "Uniswap V3 Asset Module" });

        // Add the Asset Module to the Registry.
        vm.startPrank(users.owner);
        registry.addAssetModule(address(uniV3AM));
        uniV3AM.setProtocol();
        vm.stopPrank();
    }
}
