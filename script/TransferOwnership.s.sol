/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";
import { ArcadiaAddresses, ArcadiaContractAddresses } from "./Constants/TransferOwnershipConstants.sol";

import "../src/Factory.sol";
import { MainRegistry } from "../src/MainRegistry.sol";
import { ChainlinkOracleModule } from "../src/oracle-modules/ChainlinkOracleModule.sol";
import { StandardERC20PricingModule } from "../src/pricing-modules/StandardERC20PricingModule.sol";
import { ILiquidator } from "./interfaces/ILiquidator.sol";

contract ArcadiaAccountTransferOwnership is Test {
    Factory internal factory;
    MainRegistry internal mainRegistry;
    StandardERC20PricingModule internal standardERC20PricingModule;
    ChainlinkOracleModule internal chainlinkOM;
    ILiquidator internal liquidator;

    constructor() {
        factory = Factory(ArcadiaContractAddresses.factory);
        mainRegistry = MainRegistry(ArcadiaContractAddresses.mainRegistry);
        standardERC20PricingModule = StandardERC20PricingModule(ArcadiaContractAddresses.standardERC20PricingModule);
        chainlinkOM = ChainlinkOracleModule(ArcadiaContractAddresses.chainlinkOM);
        liquidator = ILiquidator(ArcadiaContractAddresses.liquidator);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        factory.transferOwnership(ArcadiaAddresses.factoryOwner);
        mainRegistry.transferOwnership(ArcadiaAddresses.mainRegistryOwner);
        standardERC20PricingModule.transferOwnership(ArcadiaAddresses.standardERC20PricingModuleOwner);
        chainlinkOM.transferOwnership(ArcadiaAddresses.chainlinkOMOwner);
        liquidator.transferOwnership(ArcadiaAddresses.liquidatorOwner);
        vm.stopBroadcast();
    }
}
