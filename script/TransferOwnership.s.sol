/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { ArcadiaSafes, ArcadiaContracts } from "./utils/Constants.sol";

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
        factory = Factory(ArcadiaContracts.factory);
        registry = Registry(ArcadiaContracts.registry);
        erc20PrimaryAM = ERC20PrimaryAM(ArcadiaContracts.erc20PrimaryAM);
        chainlinkOM = ChainlinkOM(ArcadiaContracts.chainlinkOM);
        uniswapV3AM = UniswapV3AM(ArcadiaContracts.uniswapV3AM);
        stargateAM = StargateAM(ArcadiaContracts.stargateAM);
        stakedStargateAM = StakedStargateAM(ArcadiaContracts.stakedStargateAM);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        vm.startBroadcast(ownerPrivateKey);
        // Set guardian
        factory.changeGuardian(ArcadiaSafes.guardian);
        registry.changeGuardian(ArcadiaSafes.guardian);

        // Transfer ownership to respected addresses
        factory.transferOwnership(ArcadiaSafes.owner);
        registry.transferOwnership(ArcadiaSafes.owner);
        erc20PrimaryAM.transferOwnership(ArcadiaSafes.owner);
        chainlinkOM.transferOwnership(ArcadiaSafes.owner);
        uniswapV3AM.transferOwnership(ArcadiaSafes.owner);
        stargateAM.transferOwnership(ArcadiaSafes.owner);
        stakedStargateAM.transferOwnership(ArcadiaSafes.owner);
        vm.stopBroadcast();
    }

    function test_transferOwnership() public {
        vm.skip(true);

        assertEq(registry.guardian(), ArcadiaSafes.guardian);
        assertEq(factory.guardian(), ArcadiaSafes.guardian);

        assertEq(registry.owner(), ArcadiaSafes.owner);
        assertEq(factory.owner(), ArcadiaSafes.owner);
        assertEq(erc20PrimaryAM.owner(), ArcadiaSafes.owner);
        assertEq(chainlinkOM.owner(), ArcadiaSafes.owner);
        assertEq(uniswapV3AM.owner(), ArcadiaSafes.owner);
        assertEq(stargateAM.owner(), ArcadiaSafes.owner);
        assertEq(stakedStargateAM.owner(), ArcadiaSafes.owner);
    }
}
