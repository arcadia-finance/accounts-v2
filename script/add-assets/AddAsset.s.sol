/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AerodromeGauges, Assets, Oracles, Safes } from "../utils/constants/Base.sol";
import { Asset, Oracle } from "../utils/constants/Base.sol";
import { Base_Script } from "../Base.s.sol";

contract AddAsset is Base_Script {
    Asset internal ASSET = Assets.LBTC();
    Oracle internal ORACLE = Oracles.LBTC_USD();
    address internal SAFE = Safes.OWNER;

    constructor() { }

    function run() public {
        // Add Chainlink oracle.
        addToBatch(SAFE, address(chainlinkOM), addOracle(ORACLE));

        // Add Primary asset.
        addToBatch(SAFE, address(erc20PrimaryAM), addAsset(ASSET, ORACLE));

        // Add Aerodrome gauge to Staked Slipstream AM.
        bytes memory calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_CBBTC_LBTC));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
