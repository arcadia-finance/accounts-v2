/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { ArcadiaAddresses, ArcadiaContractAddresses } from "./Constants/TransferOwnershipConstants.sol";

import "../src/Factory.sol";
import { Registry } from "../src/Registry.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { ILiquidator } from "./interfaces/ILiquidator.sol";

contract ArcadiaAccountTransferOwnership is Test {
    Factory internal factory;
    Registry internal registry;
    ERC20PrimaryAM internal erc20PrimaryAM;
    ChainlinkOM internal chainlinkOM;
    ILiquidator internal liquidator;

    constructor() {
        factory = Factory(ArcadiaContractAddresses.factory);
        registry = Registry(ArcadiaContractAddresses.registry);
        erc20PrimaryAM = ERC20PrimaryAM(ArcadiaContractAddresses.erc20PrimaryAM);
        chainlinkOM = ChainlinkOM(ArcadiaContractAddresses.chainlinkOM);
        liquidator = ILiquidator(ArcadiaContractAddresses.liquidator);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);
        factory.transferOwnership(ArcadiaAddresses.factoryOwner);
        registry.transferOwnership(ArcadiaAddresses.registryOwner);
        erc20PrimaryAM.transferOwnership(ArcadiaAddresses.erc20PrimaryAMOwner);
        chainlinkOM.transferOwnership(ArcadiaAddresses.chainlinkOMOwner);
        liquidator.transferOwnership(ArcadiaAddresses.liquidatorOwner);
        vm.stopBroadcast();
    }
}
