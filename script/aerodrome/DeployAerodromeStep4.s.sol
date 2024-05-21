/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { AerodromeGauges, AerodromePools, ArcadiaSafes } from "../utils/Constants.sol";

contract DeployAerodromeStep4 is Base_Script {
    constructor() { }

    function run() public {
        // Initialise Asset Modules.
        vm.startBroadcast(deployer);
        slipstreamAM.setProtocol();
        stakedAerodromeAM.initialize();
        wrappedAerodromeAM.initialize();

        // Add Aerodrome pools to Aerodrome AM.
        aerodromePoolAM.addAsset(AerodromePools.V_AERO_USDBC);
        aerodromePoolAM.addAsset(AerodromePools.V_AERO_WSTETH);
        aerodromePoolAM.addAsset(AerodromePools.V_CBETH_WETH);
        aerodromePoolAM.addAsset(AerodromePools.V_USDC_AERO);
        aerodromePoolAM.addAsset(AerodromePools.V_WETH_AERO);
        aerodromePoolAM.addAsset(AerodromePools.V_WETH_USDC);
        aerodromePoolAM.addAsset(AerodromePools.V_WETH_USDBC);
        aerodromePoolAM.addAsset(AerodromePools.V_WETH_WSTETH);
        aerodromePoolAM.addAsset(AerodromePools.S_USDC_USDBC);

        // Add Aerodrome gauges to Staked Aerodrome AM.
        stakedAerodromeAM.addAsset(AerodromeGauges.V_AERO_USDBC);
        stakedAerodromeAM.addAsset(AerodromeGauges.V_AERO_WSTETH);
        stakedAerodromeAM.addAsset(AerodromeGauges.V_CBETH_WETH);
        stakedAerodromeAM.addAsset(AerodromeGauges.V_USDC_AERO);
        stakedAerodromeAM.addAsset(AerodromeGauges.V_WETH_AERO);
        stakedAerodromeAM.addAsset(AerodromeGauges.V_WETH_USDC);
        stakedAerodromeAM.addAsset(AerodromeGauges.V_WETH_USDBC);
        stakedAerodromeAM.addAsset(AerodromeGauges.V_WETH_WSTETH);
        stakedAerodromeAM.addAsset(AerodromeGauges.S_USDC_USDBC);

        // Add Aerodrome pools to Wrapped Aerodrome AM.
        wrappedAerodromeAM.addAsset(AerodromePools.V_AERO_USDBC);
        wrappedAerodromeAM.addAsset(AerodromePools.V_AERO_WSTETH);
        wrappedAerodromeAM.addAsset(AerodromePools.V_CBETH_WETH);
        wrappedAerodromeAM.addAsset(AerodromePools.V_USDC_AERO);
        wrappedAerodromeAM.addAsset(AerodromePools.V_WETH_AERO);
        wrappedAerodromeAM.addAsset(AerodromePools.V_WETH_USDC);
        wrappedAerodromeAM.addAsset(AerodromePools.V_WETH_USDBC);
        wrappedAerodromeAM.addAsset(AerodromePools.V_WETH_WSTETH);
        wrappedAerodromeAM.addAsset(AerodromePools.S_USDC_USDBC);

        // Transfer ownership to owner safe.
        aerodromePoolAM.transferOwnership(ArcadiaSafes.OWNER);
        slipstreamAM.transferOwnership(ArcadiaSafes.OWNER);
        stakedAerodromeAM.transferOwnership(ArcadiaSafes.OWNER);
        wrappedAerodromeAM.transferOwnership(ArcadiaSafes.OWNER);
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
