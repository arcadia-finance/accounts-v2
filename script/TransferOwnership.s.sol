/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { ArcadiaAddresses, ArcadiaContractAddresses } from "./Constants/TransferOwnershipConstants.sol";

import "../src/Factory.sol";
import { Registry } from "../src/Registry.sol";
import { ChainlinkOracleModule } from "../src/oracle-modules/ChainlinkOracleModule.sol";
import { StandardERC20AssetModule } from "../src/asset-modules/StandardERC20AssetModule.sol";
import { ILiquidator } from "./interfaces/ILiquidator.sol";

contract ArcadiaAccountTransferOwnership is Test {
    Factory internal factory;
    Registry internal registry;
    StandardERC20AssetModule internal standardERC20AssetModule;
    ChainlinkOracleModule internal chainlinkOM;
    ILiquidator internal liquidator;

    constructor() {
        factory = Factory(ArcadiaContractAddresses.factory);
        registry = Registry(ArcadiaContractAddresses.registry);
        standardERC20AssetModule = StandardERC20AssetModule(ArcadiaContractAddresses.standardERC20AssetModule);
        chainlinkOM = ChainlinkOracleModule(ArcadiaContractAddresses.chainlinkOM);
        liquidator = ILiquidator(ArcadiaContractAddresses.liquidator);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        factory.transferOwnership(ArcadiaAddresses.factoryOwner);
        registry.transferOwnership(ArcadiaAddresses.registryOwner);
        standardERC20AssetModule.transferOwnership(ArcadiaAddresses.standardERC20AssetModuleOwner);
        chainlinkOM.transferOwnership(ArcadiaAddresses.chainlinkOMOwner);
        liquidator.transferOwnership(ArcadiaAddresses.liquidatorOwner);
        vm.stopBroadcast();
    }
}
