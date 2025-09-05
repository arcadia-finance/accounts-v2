/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromeGauges, AerodromePools, Assets, Oracles, Safes } from "../utils/constants/Base.sol";
import { Asset, Oracle } from "../utils/constants/Base.sol";
import { Base_Script } from "../Base.s.sol";

contract AddAsset is Base_Script {
    Asset internal ASSET = Assets.VVV();
    Oracle internal ORACLE = Oracles.VVV_USD();
    address internal SAFE = Safes.OWNER;

    constructor() { }

    function run() public {
        // Add Chainlink oracle.
        addToBatch(SAFE, address(chainlinkOM), addOracle(ORACLE));

        // Add Primary asset.
        addToBatch(SAFE, address(erc20PrimaryAM), addAsset(ASSET, ORACLE));

        // Add Aerodrome pools to aerodrome AM.
        bytes memory calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_WETH_VVV));
        addToBatch(SAFE, address(aerodromePoolAM), calldata_);

        // Add Aerodrome gauge to staked Aerodrome AM.
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_WETH_VVV));
        addToBatch(SAFE, address(stakedAerodromeAM), calldata_);

        // Add Aerodrome gauge to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_WETH_VVV));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_WETH_VVV));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
