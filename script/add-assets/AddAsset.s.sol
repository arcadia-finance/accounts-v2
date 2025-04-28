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
} from "../utils/ConstantsBase.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";

contract AddAsset is Base_Script {
    uint80[] internal oracleVirtualToUsdArr = new uint80[](1);

    constructor() {
        oracleVirtualToUsdArr[0] = OracleIds.VIRTUAL_USD;
    }

    function run() public {
        // Add Chainlink oracles.
        bytes memory calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.VIRTUAL_USD, "VIRTUAL", "USD", CutOffTimes.VIRTUAL_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);

        // Add as Primary assets.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.VIRTUAL, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleVirtualToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);

        // Add Aerodrome pools to Aerodrome AM.
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_VIRTUAL_AERO));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_VIRTUAL_CBBTC));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_VIRTUAL_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);

        // Add Aerodrome gauges to Staked Aerodrome AM.
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_VIRTUAL_AERO));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_VIRTUAL_CBBTC));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_VIRTUAL_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);

        // Add Aerodrome pools to Wrapped Aerodrome AM.
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_VIRTUAL_AERO));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_VIRTUAL_CBBTC));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_VIRTUAL_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);

        // Add Aerodrome gauges to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL100_VIRTUAL_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_VIRTUAL_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));

        // Risk Parameters.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(cbbtcLendingPool),
                PrimaryAssets.VIRTUAL,
                0,
                RiskParameters.EXPOSURE_VIRTUAL_CBBTC,
                RiskParameters.COL_FAC_VIRTUAL_CBBTC,
                RiskParameters.LIQ_FAC_VIRTUAL_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.VIRTUAL,
                0,
                RiskParameters.EXPOSURE_VIRTUAL_USDC,
                RiskParameters.COL_FAC_VIRTUAL_USDC,
                RiskParameters.LIQ_FAC_VIRTUAL_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.VIRTUAL,
                0,
                RiskParameters.EXPOSURE_VIRTUAL_WETH,
                RiskParameters.COL_FAC_VIRTUAL_WETH,
                RiskParameters.LIQ_FAC_VIRTUAL_WETH
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
