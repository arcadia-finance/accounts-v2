/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import {
    AerodromeGauges,
    AerodromePools,
    ArcadiaSafes,
    CutOffTimes,
    OracleIds,
    Oracles,
    PrimaryAssets,
    RiskParameters
} from "../utils/Constants.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";

contract AddEurc is Base_Script {
    uint80[] internal oracleEurcToUsdArr = new uint80[](1);

    constructor() {
        oracleEurcToUsdArr[0] = OracleIds.EURC_USD;
    }

    function run() public {
        // Add Chainlink oracles.
        bytes memory calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.EURC_USD, "EURC", "USD", CutOffTimes.EURC_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);

        // Add as Primary assets.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.EURC, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleEurcToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);

        // Add Aerodrome pools to Aerodrome AM.
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_EURC_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_WETH_EURC));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);

        // Add Aerodrome gauges to Staked Aerodrome AM.
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_EURC_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_WETH_EURC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);

        // Add Aerodrome pools to Wrapped Aerodrome AM.
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_EURC_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_WETH_EURC));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);

        // Add Aerodrome gauges to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL50_EURC_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_EURC_CBBTC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_WETH_EURC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));

        // Risk Parameters.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(cbbtcLendingPool),
                PrimaryAssets.EURC,
                0,
                RiskParameters.EXPOSURE_EURC_CBBTC,
                RiskParameters.COL_FAC_EURC_CBBTC,
                RiskParameters.LIQ_FAC_EURC_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.EURC,
                0,
                RiskParameters.EXPOSURE_EURC_USDC,
                RiskParameters.COL_FAC_EURC_USDC,
                RiskParameters.LIQ_FAC_EURC_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.EURC,
                0,
                RiskParameters.EXPOSURE_EURC_WETH,
                RiskParameters.COL_FAC_EURC_WETH,
                RiskParameters.LIQ_FAC_EURC_WETH
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
