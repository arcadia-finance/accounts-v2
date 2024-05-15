/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { DeployAddresses } from "../utils/Constants.sol";
import { AerodromePoolAM } from "../../src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { SlipstreamAM } from "../../src/asset-modules/Slipstream/SlipstreamAM.sol";
import { StakedAerodromeAM } from "../../src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { WrappedAerodromeAM } from "../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

contract DeployAerodromeStep2 is Base_Script {
    constructor() { }

    function run() public {
        // Deploy Asset Modules.
        vm.startBroadcast(deployer);
        aerodromePoolAM = new AerodromePoolAM(address(registry), DeployAddresses.aeroFactory);
        slipstreamAM = new SlipstreamAM(address(registry), DeployAddresses.slipstreamPositionMgr);
        stakedAerodromeAM = new StakedAerodromeAM(address(registry), DeployAddresses.aeroVoter);
        wrappedAerodromeAM = new WrappedAerodromeAM(address(registry));
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
