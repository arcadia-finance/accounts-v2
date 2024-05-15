/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { AerodromePools, ArcadiaSafes } from "../utils/Constants.sol";

contract DeployAerodromeStep4 is Base_Script {
    constructor() { }

    function run() public {
        // Initialise Asset Modules.
        vm.startBroadcast(deployer);
        slipstreamAM.setProtocol();
        stakedAerodromeAM.initialize();
        wrappedAerodromeAM.initialize();

        // Add Aerodrome pools to Aerodrome AM.
        aerodromePoolAM.addAsset(AerodromePools.vAeroUsdbcPool);
        aerodromePoolAM.addAsset(AerodromePools.vAeroWstethPool);
        aerodromePoolAM.addAsset(AerodromePools.vCbethWethPool);
        aerodromePoolAM.addAsset(AerodromePools.vUsdcAeroPool);
        aerodromePoolAM.addAsset(AerodromePools.vWethAeroPool);
        aerodromePoolAM.addAsset(AerodromePools.vWethUsdcPool);
        aerodromePoolAM.addAsset(AerodromePools.vWethUsdbcPool);
        aerodromePoolAM.addAsset(AerodromePools.vWethWstethPool);
        aerodromePoolAM.addAsset(AerodromePools.sUsdcUsdbcPool);

        // Add Aerodrome gauges to Staked Aerodrome AM.
        stakedAerodromeAM.addAsset(AerodromePools.vAeroUsdbcGauge);
        stakedAerodromeAM.addAsset(AerodromePools.vAeroWstethGauge);
        stakedAerodromeAM.addAsset(AerodromePools.vCbethWethGauge);
        stakedAerodromeAM.addAsset(AerodromePools.vUsdcAeroGauge);
        stakedAerodromeAM.addAsset(AerodromePools.vWethAeroGauge);
        stakedAerodromeAM.addAsset(AerodromePools.vWethUsdcGauge);
        stakedAerodromeAM.addAsset(AerodromePools.vWethUsdbcGauge);
        stakedAerodromeAM.addAsset(AerodromePools.vWethWstethGauge);
        stakedAerodromeAM.addAsset(AerodromePools.sUsdcUsdbcGauge);

        // Add Aerodrome pools to Wrapped Aerodrome AM.
        wrappedAerodromeAM.addAsset(AerodromePools.vAeroUsdbcPool);
        wrappedAerodromeAM.addAsset(AerodromePools.vAeroWstethPool);
        wrappedAerodromeAM.addAsset(AerodromePools.vCbethWethPool);
        wrappedAerodromeAM.addAsset(AerodromePools.vUsdcAeroPool);
        wrappedAerodromeAM.addAsset(AerodromePools.vWethAeroPool);
        wrappedAerodromeAM.addAsset(AerodromePools.vWethUsdcPool);
        wrappedAerodromeAM.addAsset(AerodromePools.vWethUsdbcPool);
        wrappedAerodromeAM.addAsset(AerodromePools.vWethWstethPool);
        wrappedAerodromeAM.addAsset(AerodromePools.sUsdcUsdbcPool);

        // Transfer ownership to owner safe.
        aerodromePoolAM.transferOwnership(ArcadiaSafes.owner);
        slipstreamAM.transferOwnership(ArcadiaSafes.owner);
        stakedAerodromeAM.transferOwnership(ArcadiaSafes.owner);
        wrappedAerodromeAM.transferOwnership(ArcadiaSafes.owner);
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
