/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";
import { ArcadiaAddresses, ArcadiaContractAddresses } from "./Constants/TransferOwnershipConstants.sol";

import "../src/Factory.sol";
import {MainRegistry } from "../src/MainRegistry.sol";
import { StandardERC20PricingModule } from "../src/pricing-modules/StandardERC20PricingModule.sol";
import { ILiquidator } from "./interfaces/ILiquidator.sol";
import "../src/OracleHub.sol";

contract ArcadiaAccountTransferOwnership is Test {
    Factory public factory;
    OracleHub public oracleHub;
    MainRegistry public mainRegistry;
    StandardERC20PricingModule public standardERC20PricingModule;
    ILiquidator public liquidator;

    constructor() {
        factory = Factory(ArcadiaContractAddresses.factory);
        oracleHub = OracleHub(ArcadiaContractAddresses.oracleHub);
        mainRegistry = MainRegistry(ArcadiaContractAddresses.mainRegistry);
        standardERC20PricingModule = StandardERC20PricingModule(ArcadiaContractAddresses.standardERC20PricingModule);
        liquidator = ILiquidator(ArcadiaContractAddresses.liquidator);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        factory.transferOwnership(ArcadiaAddresses.factoryOwner);
        oracleHub.transferOwnership(ArcadiaAddresses.oracleHubOwner);
        mainRegistry.transferOwnership(ArcadiaAddresses.mainRegistryOwner);
        standardERC20PricingModule.transferOwnership(ArcadiaAddresses.standardERC20PricingModuleOwner);
        liquidator.transferOwnership(ArcadiaAddresses.liquidatorOwner);
        vm.stopBroadcast();
    }
}
