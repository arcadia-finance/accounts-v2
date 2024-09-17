/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import {
    AerodromeGauges,
    ArcadiaContracts,
    ArcadiaSafes,
    CutOffTimes,
    OracleIds,
    Oracles,
    PrimaryAssets,
    RiskParameters
} from "../utils/Constants.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";

contract AddCbbtc is Base_Script {
    uint80[] internal oracleCbbtcToUsdArr = new uint80[](1);

    constructor() {
        oracleCbbtcToUsdArr[0] = OracleIds.CBBTC_USD;
    }

    function run() public {
        // Add Chainlink oracles.
        bytes memory calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.CBBTC_USD, "CBBTC", "USD", CutOffTimes.CBBTC_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);

        // Add as Primary assets.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.CBBTC, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleCbbtcToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);

        // Add Aerodrome gauges to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_USDC_CBBTC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_WETH_CBBTC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));

        // Risk Parameters.
        // Add cbBTC to existing Lending Pools
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.CBBTC,
                0,
                RiskParameters.EXPOSURE_CBBTC_USDC,
                RiskParameters.COL_FAC_CBBTC_USDC,
                RiskParameters.LIQ_FAC_CBBTC_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.CBBTC,
                0,
                RiskParameters.EXPOSURE_CBBTC_WETH,
                RiskParameters.COL_FAC_CBBTC_WETH,
                RiskParameters.LIQ_FAC_CBBTC_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // Set risk parameters for the new cbBTC Lending Pool.
        calldata_ = abi.encodeCall(
            registry.setRiskParameters,
            (
                address(cbbtcLendingPool),
                RiskParameters.MIN_USD_VALUE_CBBTC,
                RiskParameters.GRACE_PERIOD_CBBTC,
                RiskParameters.MAX_RECURSIVE_CALLS_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // Set cbBTC risk parameters UniswapV3AM.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(cbbtcLendingPool),
                ArcadiaContracts.UNISWAPV3_AM,
                RiskParameters.EXPOSURE_UNISWAPV3_AM_CBBTC,
                RiskParameters.RISK_FAC_UNISWAPV3_AM_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // Set cbBTC risk parameters slipstreamAM.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(cbbtcLendingPool),
                address(slipstreamAM),
                RiskParameters.EXPOSURE_SLIPSTREAM_CBBTC,
                RiskParameters.RISK_FAC_SLIPSTREAM_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // Set cbBTC risk parameters staked slipstreamAM.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(cbbtcLendingPool),
                address(stakedSlipstreamAM),
                RiskParameters.EXPOSURE_STAKED_SLIPSTREAM_AM_CBBTC,
                RiskParameters.RISK_FAC_STAKED_SLIPSTREAM_AM_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // Add assets to the new cbBTC Lending Pool.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(cbbtcLendingPool),
                PrimaryAssets.AERO,
                0,
                RiskParameters.EXPOSURE_AERO_CBBTC,
                RiskParameters.COL_FAC_AERO_CBBTC,
                RiskParameters.LIQ_FAC_AERO_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(cbbtcLendingPool),
                PrimaryAssets.CBBTC,
                0,
                RiskParameters.EXPOSURE_CBBTC_CBBTC,
                RiskParameters.COL_FAC_CBBTC_CBBTC,
                RiskParameters.LIQ_FAC_CBBTC_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(cbbtcLendingPool),
                PrimaryAssets.TBTC,
                0,
                RiskParameters.EXPOSURE_TBTC_CBBTC,
                RiskParameters.COL_FAC_TBTC_CBBTC,
                RiskParameters.LIQ_FAC_TBTC_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(cbbtcLendingPool),
                PrimaryAssets.USDC,
                0,
                RiskParameters.EXPOSURE_USDC_CBBTC,
                RiskParameters.COL_FAC_USDC_CBBTC,
                RiskParameters.LIQ_FAC_USDC_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(cbbtcLendingPool),
                PrimaryAssets.WETH,
                0,
                RiskParameters.EXPOSURE_WETH_CBBTC,
                RiskParameters.COL_FAC_WETH_CBBTC,
                RiskParameters.LIQ_FAC_WETH_CBBTC
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
