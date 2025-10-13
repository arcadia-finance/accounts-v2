/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AerodromeGauges, Assets, Oracles } from "../utils/constants/Base.sol";
import { Asset, Oracle, Safes } from "../utils/constants/Shared.sol";
import { Base_Script } from "../Base.s.sol";

contract AddAsset is Base_Script {
    /// forge-lint: disable-start(mixed-case-variable)
    Asset internal ASSET = Assets.OUSDT();
    Oracle internal ORACLE = Oracles.OUSDT_USD();
    address internal SAFE = Safes.OWNER;
    /// forge-lint: disable-end(mixed-case-variable)

    constructor() { }

    function run() public {
        // Add Chainlink oracle.
        addToBatch(SAFE, address(chainlinkOM), addOracle(ORACLE));

        // Add Primary asset.
        addToBatch(SAFE, address(erc20PrimaryAM), addAsset(ASSET, ORACLE));

        // Add Aerodrome pools to aerodrome AM.

        // Add Aerodrome gauge to Staked Slipstream AM.
        bytes memory calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_WETH_CBBTC));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL2000_USDC_CBBTC));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_OUSDT_CBBTC));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_OUSDT_WETH));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_OUSDT_USDC));
        addToBatch(SAFE, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
