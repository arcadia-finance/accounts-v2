/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Script } from "../Base.s.sol";

import { AerodromeGauges, ArcadiaSafes } from "../utils/ConstantsBase.sol";

contract DeployAerodromeStep8 is Base_Script {
    constructor() { }

    function run() public {
        // Initialise Asset Modules.
        vm.startBroadcast(deployer);
        stakedSlipstreamAM.initialize();

        // Add Aerodrome gauges to Staked Slipstream AM.
        stakedSlipstreamAM.addGauge(AerodromeGauges.CL1_CBETH_WETH);
        stakedSlipstreamAM.addGauge(AerodromeGauges.CL1_USDC_USDBC);
        stakedSlipstreamAM.addGauge(AerodromeGauges.CL1_WETH_WSTETH);
        stakedSlipstreamAM.addGauge(AerodromeGauges.CL100_WETH_USDC);
        stakedSlipstreamAM.addGauge(AerodromeGauges.CL200_AERO_WSTETH);
        stakedSlipstreamAM.addGauge(AerodromeGauges.CL200_WETH_AERO);

        // Transfer ownership to owner safe.
        stakedSlipstreamAM.transferOwnership(ArcadiaSafes.OWNER);
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
