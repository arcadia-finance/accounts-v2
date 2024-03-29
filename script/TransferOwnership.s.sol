/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { ArcadiaAddresses, ArcadiaContractAddresses } from "./Constants/TransferOwnershipConstants.sol";

import { Factory } from "../src/Factory.sol";
import { Registry } from "../src/Registry.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { UniswapV3AM } from "../src/asset-modules/UniswapV3/UniswapV3AM.sol";
import { StargateAM } from "./../src/asset-modules/Stargate-Finance/StargateAM.sol";
import { StakedStargateAM } from "./../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";

contract ArcadiaAccountTransferOwnership is Test {
    Factory internal factory;
    Registry internal registry;
    ERC20PrimaryAM internal erc20PrimaryAM;
    ChainlinkOM internal chainlinkOM;
    UniswapV3AM internal uniswapV3AM;
    StargateAM internal stargateAM;
    StakedStargateAM internal stakedStargateAM;

    constructor() {
        factory = Factory(ArcadiaContractAddresses.factory);
        registry = Registry(ArcadiaContractAddresses.registry);
        erc20PrimaryAM = ERC20PrimaryAM(ArcadiaContractAddresses.erc20PrimaryAM);
        chainlinkOM = ChainlinkOM(ArcadiaContractAddresses.chainlinkOM);
        uniswapV3AM = UniswapV3AM(ArcadiaContractAddresses.uniswapV3AM);
        stargateAM = StargateAM(ArcadiaContractAddresses.stargateAM);
        stakedStargateAM = StakedStargateAM(ArcadiaContractAddresses.stakedStargateAM);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        vm.startBroadcast(ownerPrivateKey);
        // Set guardian
        factory.changeGuardian(ArcadiaAddresses.guardian);
        registry.changeGuardian(ArcadiaAddresses.guardian);

        // Transfer ownership to respected addresses
        factory.transferOwnership(ArcadiaAddresses.owner);
        registry.transferOwnership(ArcadiaAddresses.owner);
        erc20PrimaryAM.transferOwnership(ArcadiaAddresses.owner);
        chainlinkOM.transferOwnership(ArcadiaAddresses.owner);
        uniswapV3AM.transferOwnership(ArcadiaAddresses.owner);
        stargateAM.transferOwnership(ArcadiaAddresses.owner);
        stakedStargateAM.transferOwnership(ArcadiaAddresses.owner);
        vm.stopBroadcast();
    }

    function test_transferOwnership() public {
        vm.skip(true);

        assertEq(registry.guardian(), ArcadiaAddresses.guardian);
        assertEq(factory.guardian(), ArcadiaAddresses.guardian);

        assertEq(registry.owner(), ArcadiaAddresses.owner);
        assertEq(factory.owner(), ArcadiaAddresses.owner);
        assertEq(erc20PrimaryAM.owner(), ArcadiaAddresses.owner);
        assertEq(chainlinkOM.owner(), ArcadiaAddresses.owner);
        assertEq(uniswapV3AM.owner(), ArcadiaAddresses.owner);
        assertEq(stargateAM.owner(), ArcadiaAddresses.owner);
        assertEq(stakedStargateAM.owner(), ArcadiaAddresses.owner);
    }
}
