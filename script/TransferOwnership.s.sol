/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Test } from "../lib/forge-std/src/Test.sol";

import { ArcadiaContracts, ArcadiaSafes } from "./utils/ConstantsBase.sol";
import { ChainlinkOM } from "../src/oracle-modules/ChainlinkOM.sol";
import { ERC20PrimaryAM } from "../src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { Factory } from "../src/Factory.sol";
import { Registry } from "../src/Registry.sol";
import { StakedStargateAM } from "./../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";
import { StargateAM } from "./../src/asset-modules/Stargate-Finance/StargateAM.sol";
import { UniswapV3AM } from "../src/asset-modules/UniswapV3/UniswapV3AM.sol";

contract ArcadiaAccountTransferOwnership is Test {
    Factory internal factory;
    Registry internal registry;
    ERC20PrimaryAM internal erc20PrimaryAM;
    ChainlinkOM internal chainlinkOM;
    UniswapV3AM internal uniswapV3AM;
    StargateAM internal stargateAM;
    StakedStargateAM internal stakedStargateAM;

    constructor() {
        factory = Factory(ArcadiaContracts.FACTORY);
        registry = Registry(ArcadiaContracts.REGISTRY);
        erc20PrimaryAM = ERC20PrimaryAM(ArcadiaContracts.ERC20_PRIMARY_AM);
        chainlinkOM = ChainlinkOM(ArcadiaContracts.CHAINLINK_OM);
        uniswapV3AM = UniswapV3AM(ArcadiaContracts.UNISWAPV3_AM);
        stargateAM = StargateAM(ArcadiaContracts.STARGATE_AM);
        stakedStargateAM = StakedStargateAM(ArcadiaContracts.STAKED_STARGATE_AM);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER");
        vm.startBroadcast(ownerPrivateKey);
        // Set guardian
        factory.changeGuardian(ArcadiaSafes.GUARDIAN);
        registry.changeGuardian(ArcadiaSafes.GUARDIAN);

        // Transfer ownership to respected addresses
        factory.transferOwnership(ArcadiaSafes.OWNER);
        registry.transferOwnership(ArcadiaSafes.OWNER);
        erc20PrimaryAM.transferOwnership(ArcadiaSafes.OWNER);
        chainlinkOM.transferOwnership(ArcadiaSafes.OWNER);
        uniswapV3AM.transferOwnership(ArcadiaSafes.OWNER);
        stargateAM.transferOwnership(ArcadiaSafes.OWNER);
        stakedStargateAM.transferOwnership(ArcadiaSafes.OWNER);
        vm.stopBroadcast();
    }

    function test_transferOwnership() public {
        vm.skip(true);

        assertEq(registry.guardian(), ArcadiaSafes.GUARDIAN);
        assertEq(factory.guardian(), ArcadiaSafes.GUARDIAN);

        assertEq(registry.owner(), ArcadiaSafes.OWNER);
        assertEq(factory.owner(), ArcadiaSafes.OWNER);
        assertEq(erc20PrimaryAM.owner(), ArcadiaSafes.OWNER);
        assertEq(chainlinkOM.owner(), ArcadiaSafes.OWNER);
        assertEq(uniswapV3AM.owner(), ArcadiaSafes.OWNER);
        assertEq(stargateAM.owner(), ArcadiaSafes.OWNER);
        assertEq(stakedStargateAM.owner(), ArcadiaSafes.OWNER);
    }
}
