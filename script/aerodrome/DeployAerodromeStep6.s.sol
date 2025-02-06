/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ExternalContracts, PrimaryAssets } from "../utils/Constants.sol";
import { StakedSlipstreamAM } from "../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";

contract DeployAerodromeStep6 is Base_Script {
    constructor() { }

    function run() public {
        // Deploy Asset Modules.
        vm.startBroadcast(deployer);
        stakedSlipstreamAM = new StakedSlipstreamAM(
            address(registry), ExternalContracts.SLIPSTREAM_POS_MNGR, ExternalContracts.AERO_VOTER, PrimaryAssets.AERO
        );
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
