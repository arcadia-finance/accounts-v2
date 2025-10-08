/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromeGauges, AerodromePools, Assets, Oracles } from "../utils/constants/Base.sol";
import { Base_Script } from "../Base.s.sol";
import { Safes } from "../utils/constants/Shared.sol";

contract AddAssets is Base_Script {
    /// forge-lint: disable-next-line(mixed-case-variable)
    address internal SAFE = Safes.OWNER;

    constructor() { }

    function run() public {
        // Add Chainlink oracles.
        addToBatch(SAFE, address(chainlinkOM), addOracle(Oracles.AAVE_USD()));
        addToBatch(SAFE, address(chainlinkOM), addOracle(Oracles.GHO_USD()));
        addToBatch(SAFE, address(chainlinkOM), addOracle(Oracles.MORPHO_USD()));
        addToBatch(SAFE, address(chainlinkOM), addOracle(Oracles.WELL_USD()));

        // Add Primary assets.
        addToBatch(SAFE, address(erc20PrimaryAM), addAsset(Assets.AAVE(), Oracles.AAVE_USD()));
        addToBatch(SAFE, address(erc20PrimaryAM), addAsset(Assets.GHO(), Oracles.GHO_USD()));
        addToBatch(SAFE, address(erc20PrimaryAM), addAsset(Assets.MORPHO(), Oracles.MORPHO_USD()));
        addToBatch(SAFE, address(erc20PrimaryAM), addAsset(Assets.WELL(), Oracles.WELL_USD()));

        // Add Aerodrome pools to aerodrome AM.
        bytes memory calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_AERO_WELL));
        addToBatch(SAFE, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_WETH_WELL));
        addToBatch(SAFE, address(aerodromePoolAM), calldata_);

        // Add Aerodrome gauge to staked Aerodrome AM.
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_AERO_WELL));
        addToBatch(SAFE, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_WETH_WELL));
        addToBatch(SAFE, address(stakedAerodromeAM), calldata_);

        // Add Aerodrome gauge to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_WETH_AAVE));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_WETH_MORPHO));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_WETH_WELL));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
