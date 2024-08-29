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

contract AddTbtcAndRdnt is Base_Script {
    uint80[] internal oracleRdntToUsdArr = new uint80[](1);
    uint80[] internal oracleTbtcToUsdArr = new uint80[](1);

    constructor() {
        oracleRdntToUsdArr[0] = OracleIds.RDNT_USD;
        oracleTbtcToUsdArr[0] = OracleIds.TBTC_USD;
    }

    function run() public {
        // Add Chainlink oracles.
        bytes memory calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.RDNT_USD, "RDNT", "USD", CutOffTimes.RDNT_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);
        calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.TBTC_USD, "TBTC", "USD", CutOffTimes.TBTC_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);

        // Add as Primary assets.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.RDNT, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleRdntToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.TBTC, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleTbtcToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);

        // Add Aerodrome gauges to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_TBTC_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_TBTC_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_WETH_RDNT));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));

        // Risk Parameters.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.RDNT,
                0,
                RiskParameters.EXPOSURE_RDNT_USDC,
                RiskParameters.COL_FAC_RDNT_USDC,
                RiskParameters.LIQ_FAC_RDNT_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.RDNT,
                0,
                RiskParameters.EXPOSURE_RDNT_WETH,
                RiskParameters.COL_FAC_RDNT_WETH,
                RiskParameters.LIQ_FAC_RDNT_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.TBTC,
                0,
                RiskParameters.EXPOSURE_TBTC_USDC,
                RiskParameters.COL_FAC_TBTC_USDC,
                RiskParameters.LIQ_FAC_TBTC_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.TBTC,
                0,
                RiskParameters.EXPOSURE_TBTC_WETH,
                RiskParameters.COL_FAC_TBTC_WETH,
                RiskParameters.LIQ_FAC_TBTC_WETH
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
