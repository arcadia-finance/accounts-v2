/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromeGauges } from "../utils/constants/Base.sol";
import { Base_Script } from "../Base.s.sol";
import { Safes } from "../utils/constants/Shared.sol";

contract AddPool is Base_Script {
    /// forge-lint: disable-next-line(mixed-case-variable)
    address internal SAFE = Safes.OWNER;

    constructor() { }

    function run() public {
        // Add Aerodrome gauge to Staked Slipstream AM.
        addToBatch(
            SAFE,
            address(stakedSlipstreamAM),
            abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_WETH_USDC))
        );

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
