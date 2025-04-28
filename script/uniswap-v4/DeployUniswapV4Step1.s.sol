/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, ExternalContracts } from "../utils/ConstantsBase.sol";
import { DefaultUniswapV4AM } from "../../src/asset-modules/UniswapV4/DefaultUniswapV4AM.sol";
import { UniswapV4HooksRegistry } from "../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

contract DeployUniswapV4Step1 is Base_Script {
    constructor() { }

    function run() public {
        // Sanity check that we use the correct priv key.
        require(vm.addr(deployer) == 0x0f518becFC14125F23b8422849f6393D59627ddB, "Wrong Deployer.");

        // Deploy Asset Module.
        vm.startBroadcast(deployer);
        UniswapV4HooksRegistry uniswapV4HooksRegistry =
            new UniswapV4HooksRegistry(address(registry), ExternalContracts.UNISWAPV4_POS_MNGR);
        DefaultUniswapV4AM defaultUniswapV4AM = DefaultUniswapV4AM(uniswapV4HooksRegistry.DEFAULT_UNISWAP_V4_AM());

        uniswapV4HooksRegistry.transferOwnership(ArcadiaSafes.OWNER);
        defaultUniswapV4AM.transferOwnership(ArcadiaSafes.OWNER);
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
