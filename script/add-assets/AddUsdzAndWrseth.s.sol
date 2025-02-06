/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

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

contract AddUsdzAndWrseth is Base_Script {
    uint80[] internal oracleUsdzToUsdArr = new uint80[](1);
    uint80[] internal oracleWrsethToEthToUsdArr = new uint80[](2);

    constructor() {
        oracleUsdzToUsdArr[0] = OracleIds.USDZ_USD;
        oracleWrsethToEthToUsdArr[0] = OracleIds.WRSETH_ETH;
        oracleWrsethToEthToUsdArr[1] = OracleIds.ETH_USD;
    }

    function run() public {
        // Add Chainlink oracles.
        bytes memory calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.USDZ_USD, "USDZ", "USD", CutOffTimes.USDZ_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);
        calldata_ = abi.encodeCall(chainlinkOM.addOracle, (Oracles.WRSETH_ETH, "WRSETH", "ETH", CutOffTimes.WRSETH_ETH));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);

        // Add Primary assets.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.USDZ, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleUsdzToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset,
            (PrimaryAssets.WRSETH, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleWrsethToEthToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);

        // Add Aerodrome pools to Aerodrome AM.
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.S_USDZ_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_USDZ_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_WETH_WRSETH));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);

        // Add Aerodrome gauges to Staked Aerodrome AM.
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.S_USDZ_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_USDZ_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_WETH_WRSETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);

        // Add Aerodrome pools to Wrapped Aerodrome AM.
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.S_USDZ_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_USDZ_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_WETH_WRSETH));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);

        // Add Aerodrome gauges to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_USDZ_USDC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_WETH_WRSETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_WSTETH_WRSETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_USDZ_CBBTC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_USDZ_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_USDZ_DEGEN));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));

        // Risk Parameters.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(cbbtcLendingPool),
                PrimaryAssets.USDZ,
                0,
                RiskParameters.EXPOSURE_USDZ_CBBTC,
                RiskParameters.COL_FAC_USDZ_CBBTC,
                RiskParameters.LIQ_FAC_USDZ_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.USDZ,
                0,
                RiskParameters.EXPOSURE_USDZ_USDC,
                RiskParameters.COL_FAC_USDZ_USDC,
                RiskParameters.LIQ_FAC_USDZ_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.USDZ,
                0,
                RiskParameters.EXPOSURE_USDZ_WETH,
                RiskParameters.COL_FAC_USDZ_WETH,
                RiskParameters.LIQ_FAC_USDZ_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.WRSETH,
                0,
                RiskParameters.EXPOSURE_WRSETH_USDC,
                RiskParameters.COL_FAC_WRSETH_USDC,
                RiskParameters.LIQ_FAC_WRSETH_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.WRSETH,
                0,
                RiskParameters.EXPOSURE_WRSETH_WETH,
                RiskParameters.COL_FAC_WRSETH_WETH,
                RiskParameters.LIQ_FAC_WRSETH_WETH
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
