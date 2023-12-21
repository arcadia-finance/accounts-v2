/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Test } from "../lib/forge-std/src/Test.sol";
import { Users } from "./utils/Types.sol";
import { Factory } from "../src/Factory.sol";
import { AccountV1 } from "../src/accounts/AccountV1.sol";
import { AccountV2 } from "./utils/mocks/AccountV2.sol";
import { SequencerUptimeOracle } from "./utils/mocks/SequencerUptimeOracle.sol";
import { ChainlinkOracleModuleExtension } from "./utils/Extensions.sol";
import { RegistryExtension } from "./utils/Extensions.sol";
import { AssetModule } from "../src/asset-modules/AbstractAssetModule.sol";
import { StandardERC20AssetModuleExtension } from "./utils/Extensions.sol";
import { FloorERC721AssetModuleExtension } from "./utils/Extensions.sol";
import { FloorERC1155AssetModuleExtension } from "./utils/Extensions.sol";
import { UniswapV3AssetModuleExtension } from "./utils/Extensions.sol";
import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";
import { Errors } from "./utils/Errors.sol";
import { Utils } from "./utils/Utils.sol";
import { ERC721TokenReceiver } from "../lib/solmate/src/tokens/ERC721.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Events, Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Factory internal factory;
    RegistryExtension internal registryExtension;
    ChainlinkOracleModuleExtension internal chainlinkOM;
    StandardERC20AssetModuleExtension internal erc20AssetModule;
    FloorERC721AssetModuleExtension internal floorERC721AssetModule;
    FloorERC1155AssetModuleExtension internal floorERC1155AssetModule;
    UniswapV3AssetModuleExtension internal uniV3AssetModule;
    AccountV1 internal accountV1Logic;
    AccountV2 internal accountV2Logic;
    AccountV1 internal proxyAccount;
    SequencerUptimeOracle internal sequencerUptimeOracle;

    /*//////////////////////////////////////////////////////////////////////////
                                   MODIFIERS
    //////////////////////////////////////////////////////////////////////////*/

    modifier canReceiveERC721(address to) {
        if (to.code.length != 0) {
            try ERC721TokenReceiver(to).onERC721Received(to, address(0), 0, "") returns (bytes4 response) {
                vm.assume(response == ERC721TokenReceiver.onERC721Received.selector);
            } catch {
                vm.assume(false);
            }
        }
        _;
    }

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
            defaultTransmitter: createUser("defaultTransmitter"),
            swapper: createUser("swapper"),
            guardian: createUser("guardian"),
            riskManager: createUser("riskManager")
        });

        // Deploy the sequencer uptime oracle.
        sequencerUptimeOracle = new SequencerUptimeOracle();

        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        factory = new Factory();
        registryExtension = new RegistryExtension(address(factory), address(sequencerUptimeOracle));
        chainlinkOM = new ChainlinkOracleModuleExtension(address(registryExtension));
        erc20AssetModule = new StandardERC20AssetModuleExtension(address(registryExtension));
        floorERC721AssetModule = new FloorERC721AssetModuleExtension(address(registryExtension));
        floorERC1155AssetModule = new FloorERC1155AssetModuleExtension(address(registryExtension));

        accountV1Logic = new AccountV1(address(factory));
        accountV2Logic = new AccountV2(address(factory));
        factory.setNewAccountInfo(address(registryExtension), address(accountV1Logic), Constants.upgradeProof1To2, "");

        // Set the Guardians.
        vm.startPrank(users.creatorAddress);
        factory.changeGuardian(users.guardian);
        registryExtension.changeGuardian(users.guardian);

        // Add Asset Modules to the Registry.
        vm.startPrank(users.creatorAddress);
        registryExtension.addAssetModule(address(erc20AssetModule));
        registryExtension.addAssetModule(address(floorERC721AssetModule));
        registryExtension.addAssetModule(address(floorERC1155AssetModule));
        vm.stopPrank();

        // Add Oracle Modules to the Registry.
        vm.startPrank(users.creatorAddress);
        registryExtension.addOracleModule(address(chainlinkOM));
        vm.stopPrank();

        // Label the base test contracts.
        vm.label({ account: address(factory), newLabel: "Factory" });
        vm.label({ account: address(registryExtension), newLabel: "Registry" });
        vm.label({ account: address(chainlinkOM), newLabel: "Chainlink Oracle Module" });
        vm.label({ account: address(erc20AssetModule), newLabel: "Standard ERC20 Asset Module" });
        vm.label({ account: address(floorERC721AssetModule), newLabel: "ERC721 Asset Module" });
        vm.label({ account: address(floorERC1155AssetModule), newLabel: "ERC1155 Asset Module" });
        vm.label({ account: address(accountV1Logic), newLabel: "Account V1 Logic" });
        vm.label({ account: address(accountV2Logic), newLabel: "Account V2 Logic" });

        // Deploy an initial Account with all inputs to zero
        vm.startPrank(users.accountOwner);
        address proxyAddress = factory.createAccount(0, 0, address(0));
        proxyAccount = AccountV1(proxyAddress);
        vm.stopPrank();

        // Warp to have a timestamp of at least two days old.
        vm.warp(2 days);
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

    function deployUniswapV3AssetModule(address nonfungiblePositionManager_) internal {
        // Get the bytecode of the UniswapV3PoolExtension.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV3PoolExtension.sol"), args);
        bytes32 poolExtensionInitCodeHash = keccak256(bytecode);

        // Get the bytecode of UniswapV3AssetModuleExtension.
        args = abi.encode(address(registryExtension), nonfungiblePositionManager_);
        bytecode = abi.encodePacked(vm.getCode("Extensions.sol:UniswapV3AssetModuleExtension"), args);

        // Overwrite constant in bytecode of NonfungiblePositionManager.
        // -> Replace the code hash of UniswapV3Pool.sol with the code hash of UniswapV3PoolExtension.sol
        bytes32 POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytecode = Utils.veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);

        // Deploy UniswapV3PoolExtension with modified bytecode.
        vm.prank(users.creatorAddress);
        address uniV3AssetModule_ = Utils.deployBytecode(bytecode);
        uniV3AssetModule = UniswapV3AssetModuleExtension(uniV3AssetModule_);

        vm.label({ account: address(uniV3AssetModule), newLabel: "Uniswap V3 Asset Module" });

        // Add the Asset Module to the Registry.
        vm.startPrank(users.creatorAddress);
        registryExtension.addAssetModule(address(uniV3AssetModule));
        uniV3AssetModule.setProtocol();
        vm.stopPrank();
    }
}
