/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Test } from "../lib/forge-std/src/Test.sol";
import { Users, MockOracles, MockERC20, MockERC721, Rates } from "./utils/Types.sol";
import { Factory } from "../src/Factory.sol";
import { AccountV1 } from "../src/AccountV1.sol";
import { AccountV2 } from "./utils/mocks/AccountV2.sol";
import { MainRegistryExtension } from "./utils/Extensions.sol";
import { PricingModule } from "../src/pricing-modules/AbstractPricingModule.sol";
import { OracleHub } from "../src/OracleHub.sol";
import { StandardERC20PricingModule } from "../src/pricing-modules/StandardERC20PricingModule.sol";
import { FloorERC721PricingModule } from "../src/pricing-modules/FloorERC721PricingModule.sol";
import { FloorERC1155PricingModule } from "../src/pricing-modules/FloorERC1155PricingModule.sol";
import { UniswapV3PricingModuleExtension } from "./utils/Extensions.sol";
import { TrustedCreditorMock } from "./utils/mocks/TrustedCreditorMock.sol";
import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";
import { Errors } from "./utils/Errors.sol";
import { Utils } from "./utils/Utils.sol";
import { ERC20Mock } from "./utils/mocks/ERC20Mock.sol";
import { ERC721Mock } from "./utils/mocks/ERC721Mock.sol";
import { ERC1155Mock } from "./utils/mocks/ERC1155Mock.sol";

/// @notice Base test contract with common logic needed by all tests.
abstract contract Base_Test is Test, Events, Errors {
    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    Users internal users;

    // This will be the base currency set for the instance of "trustedCreditorWithParams"
    address internal initBaseCurrency;

    PricingModule.RiskVarInput[] emptyRiskVarInput;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Factory internal factory;
    MainRegistryExtension internal mainRegistryExtension;
    OracleHub internal oracleHub;
    StandardERC20PricingModule internal erc20PricingModule;
    FloorERC721PricingModule internal floorERC721PricingModule;
    FloorERC1155PricingModule internal floorERC1155PricingModule;
    UniswapV3PricingModuleExtension internal uniV3PricingModule;
    AccountV1 internal accountV1Logic;
    AccountV2 internal accountV2Logic;
    AccountV1 internal proxyAccount;
    TrustedCreditorMock internal trustedCreditor;

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
            guardian: createUser("guardian")
        });

        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        factory = new Factory();
        mainRegistryExtension = new MainRegistryExtension(address(factory));
        oracleHub = new OracleHub();
        erc20PricingModule = new StandardERC20PricingModule(address(mainRegistryExtension), address(oracleHub), 0);
        floorERC721PricingModule = new FloorERC721PricingModule(address(mainRegistryExtension), address(oracleHub), 1);
        floorERC1155PricingModule = new FloorERC1155PricingModule(
            address(mainRegistryExtension),
            address(oracleHub),
            2
        );
        accountV1Logic = new AccountV1();
        accountV2Logic = new AccountV2();
        factory.setNewAccountInfo(
            address(mainRegistryExtension), address(accountV1Logic), Constants.upgradeProof1To2, ""
        );
        trustedCreditor = new TrustedCreditorMock();
        vm.stopPrank();

        // Set the Guardians.
        vm.startPrank(users.creatorAddress);
        factory.changeGuardian(users.guardian);
        mainRegistryExtension.changeGuardian(users.guardian);
        vm.stopPrank();

        // Add Pricing Modules to the Main Registry.
        vm.startPrank(users.creatorAddress);
        mainRegistryExtension.addPricingModule(address(erc20PricingModule));
        mainRegistryExtension.addPricingModule(address(floorERC721PricingModule));
        mainRegistryExtension.addPricingModule(address(floorERC1155PricingModule));
        vm.stopPrank();

        // Label the base test contracts.
        vm.label({ account: address(factory), newLabel: "Factory" });
        vm.label({ account: address(mainRegistryExtension), newLabel: "Main Registry" });
        vm.label({ account: address(oracleHub), newLabel: "Oracle Hub" });
        vm.label({ account: address(erc20PricingModule), newLabel: "Standard ERC20 Pricing Module" });
        vm.label({ account: address(floorERC721PricingModule), newLabel: "ERC721 Pricing Module" });
        vm.label({ account: address(floorERC1155PricingModule), newLabel: "ERC1155 Pricing Module" });
        vm.label({ account: address(accountV1Logic), newLabel: "Account V1 Logic" });
        vm.label({ account: address(accountV2Logic), newLabel: "Account V2 Logic" });
        vm.label({ account: address(trustedCreditor), newLabel: "Mocked Trusted Creditor" });

        // Initialize the default liquidation cost and liquidator of trusted creditor
        // The base currency on initialization will depend on the type of test and set at a lower level
        trustedCreditor.setFixedLiquidationCost(Constants.initLiquidationCost);
        trustedCreditor.setLiquidator(Constants.initLiquidator);

        // Deploy an initial Account with all inputs to zero
        vm.prank(users.accountOwner);
        address proxyAddress = factory.createAccount(0, 0, address(0), address(0));
        proxyAccount = AccountV1(proxyAddress);
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

    function deployUniswapV3PricingModule() internal {
        // Get the bytecode of the UniswapV3PoolExtension.
        bytes memory args = abi.encode();
        bytes memory bytecode = abi.encodePacked(vm.getCode("UniswapV3PoolExtension.sol"), args);
        bytes32 poolExtensionInitCodeHash = keccak256(bytecode);

        // Get the bytecode of UniswapV3PricingModuleExtension.
        args = abi.encode(
            address(mainRegistryExtension), address(oracleHub), users.creatorAddress, address(erc20PricingModule)
        );
        bytecode = abi.encodePacked(vm.getCode("Extensions.sol:UniswapV3PricingModuleExtension"), args);

        // Overwrite constant in bytecode of NonfungiblePositionManager.
        // -> Replace the code hash of UniswapV3Pool.sol with the code hash of UniswapV3PoolExtension.sol
        bytes32 POOL_INIT_CODE_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;
        bytecode = Utils.veryBadBytesReplacer(bytecode, POOL_INIT_CODE_HASH, poolExtensionInitCodeHash);

        // Deploy UniswapV3PoolExtension with modified bytecode.
        vm.prank(users.creatorAddress);
        address uniV3PricingModule_ = Utils.deployBytecode(bytecode);
        uniV3PricingModule = UniswapV3PricingModuleExtension(uniV3PricingModule_);

        vm.label({ account: address(uniV3PricingModule), newLabel: "Uniswap V3 Pricing Module" });

        // Add the Pricing Module to the MainRegistry.
        vm.prank(users.creatorAddress);
        mainRegistryExtension.addPricingModule(address(uniV3PricingModule));
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/
}
