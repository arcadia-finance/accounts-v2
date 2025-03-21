/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import {
    AerodromeGauges,
    ArcadiaSafes,
    CutOffTimes,
    OracleIds,
    Oracles,
    PrimaryAssets,
    RiskParameters
} from "../utils/Constants.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";

contract AddTrump is Base_Script {
    uint80[] internal oracleTrumpToUsdArr = new uint80[](1);

    constructor() {
        oracleTrumpToUsdArr[0] = OracleIds.TRUMP_USD;
    }

    function run() public {
        // Add Chainlink oracles.
        bytes memory calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.TRUMP_USD, "TRUMP", "USD", CutOffTimes.TRUMP_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);

        // Add as Primary assets.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.TRUMP, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleTrumpToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);

        // Add Aerodrome gauges to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_EURC_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_USDC_TRUMP));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));

        // Risk Parameters.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.TRUMP,
                0,
                RiskParameters.EXPOSURE_TRUMP_USDC,
                RiskParameters.COL_FAC_TRUMP_USDC,
                RiskParameters.LIQ_FAC_TRUMP_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.TRUMP,
                0,
                RiskParameters.EXPOSURE_TRUMP_WETH,
                RiskParameters.COL_FAC_TRUMP_WETH,
                RiskParameters.LIQ_FAC_TRUMP_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        data = createBatchedData(ArcadiaSafes.RISK_MANAGER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
