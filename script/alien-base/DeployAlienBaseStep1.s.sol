/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, ExternalContracts } from "../utils/Constants.sol";
import { UniswapV3AM } from "../../src/asset-modules/UniswapV3/UniswapV3AM.sol";

contract DeployAlienBaseStep1 is Base_Script {
    constructor() { }

    function run() public {
        // Deploy Asset Module.
        vm.startBroadcast(deployer);
        alienBaseAM = new UniswapV3AM(address(registry), ExternalContracts.ALIEN_BASE_POS_MNGR);
        alienBaseAM.transferOwnership(ArcadiaSafes.OWNER);
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
