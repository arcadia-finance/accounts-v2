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
import { ERC20PrimaryAssetModule } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAssetModule.sol";
import { ILiquidator } from "./interfaces/ILiquidator.sol";

contract ArcadiaAccountTransferOwnership is Test {
    Factory internal factory;
    Registry internal registry;
    ERC20PrimaryAssetModule internal erc20PrimaryAssetModule;
    ChainlinkOracleModule internal chainlinkOM;
    ILiquidator internal liquidator;

    constructor() {
        factory = Factory(ArcadiaContractAddresses.factory);
        registry = Registry(ArcadiaContractAddresses.registry);
        erc20PrimaryAssetModule = ERC20PrimaryAssetModule(ArcadiaContractAddresses.erc20PrimaryAssetModule);
        chainlinkOM = ChainlinkOracleModule(ArcadiaContractAddresses.chainlinkOM);
        liquidator = ILiquidator(ArcadiaContractAddresses.liquidator);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        factory.transferOwnership(ArcadiaAddresses.factoryOwner);
        registry.transferOwnership(ArcadiaAddresses.registryOwner);
        erc20PrimaryAssetModule.transferOwnership(ArcadiaAddresses.erc20PrimaryAssetModuleOwner);
        chainlinkOM.transferOwnership(ArcadiaAddresses.chainlinkOMOwner);
        liquidator.transferOwnership(ArcadiaAddresses.liquidatorOwner);
        vm.stopBroadcast();
    }
}
