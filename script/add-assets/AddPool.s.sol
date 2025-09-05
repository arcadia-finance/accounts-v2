/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromeGauges, AerodromePools, Assets, Oracles, Safes } from "../utils/constants/Base.sol";
import { Asset, Oracle } from "../utils/constants/Base.sol";
import { Base_Script } from "../Base.s.sol";

contract AddPool is Base_Script {
    address internal SAFE = Safes.OWNER;

    constructor() { }

    function run() public {
        // Add Aerodrome gauge to Staked Slipstream AM.
        addToBatch(
            SAFE,
            address(stakedSlipstreamAM),
            abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL2000_USDC_AERO))
        );

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
