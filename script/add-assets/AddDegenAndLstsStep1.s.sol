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
    PrimaryAssets
} from "../utils/Constants.sol";
import { BitPackingLib } from "../../src/libraries/BitPackingLib.sol";

contract AddDegenAndLstsStep1 is Base_Script {
    uint80[] internal oracleDegenToUsdArr = new uint80[](1);
    uint80[] internal oracleEzethToEthToUsdArr = new uint80[](2);
    uint80[] internal oracleWeethToEthToUsdArr = new uint80[](2);

    constructor() {
        oracleDegenToUsdArr[0] = OracleIds.DEGEN_USD;
        oracleEzethToEthToUsdArr[0] = OracleIds.EZETH_ETH;
        oracleEzethToEthToUsdArr[1] = OracleIds.ETH_USD;
        oracleWeethToEthToUsdArr[0] = OracleIds.WEETH_ETH;
        oracleWeethToEthToUsdArr[1] = OracleIds.ETH_USD;
    }

    function run() public {
        // Add Chainlink oracles.
        bytes memory calldata_ =
            abi.encodeCall(chainlinkOM.addOracle, (Oracles.DEGEN_USD, "DEGEN", "USD", CutOffTimes.DEGEN_USD));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);
        calldata_ = abi.encodeCall(chainlinkOM.addOracle, (Oracles.EZETH_ETH, "ezETH", "ETH", CutOffTimes.EZETH_ETH));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);
        calldata_ = abi.encodeCall(chainlinkOM.addOracle, (Oracles.WEETH_ETH, "weETH", "ETH", CutOffTimes.WEETH_ETH));
        addToBatch(ArcadiaSafes.OWNER, address(chainlinkOM), calldata_);

        // Add as Primary assets.
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset, (PrimaryAssets.DEGEN, BitPackingLib.pack(BA_TO_QA_SINGLE, oracleDegenToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset,
            (PrimaryAssets.EZETH, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleEzethToEthToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);
        calldata_ = abi.encodeCall(
            erc20PrimaryAM.addAsset,
            (PrimaryAssets.WEETH, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleWeethToEthToUsdArr))
        );
        addToBatch(ArcadiaSafes.OWNER, address(erc20PrimaryAM), calldata_);

        // Add Aerodrome pools to Aerodrome AM.
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.S_EZETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_EZETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_WEETH_AERO));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_WEETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);
        calldata_ = abi.encodeCall(aerodromePoolAM.addAsset, (AerodromePools.V_WETH_DEGEN));
        addToBatch(ArcadiaSafes.OWNER, address(aerodromePoolAM), calldata_);

        // Add Aerodrome gauges to Staked Aerodrome AM.
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.S_EZETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_EZETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_WEETH_AERO));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_WEETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(stakedAerodromeAM.addAsset, (AerodromeGauges.V_WETH_DEGEN));
        addToBatch(ArcadiaSafes.OWNER, address(stakedAerodromeAM), calldata_);

        // Add Aerodrome pools to Wrapped Aerodrome AM.
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.S_EZETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_EZETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_WEETH_AERO));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_WEETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);
        calldata_ = abi.encodeCall(wrappedAerodromeAM.addAsset, (AerodromePools.V_WETH_DEGEN));
        addToBatch(ArcadiaSafes.OWNER, address(wrappedAerodromeAM), calldata_);

        // Add Aerodrome gauges to Staked Slipstream AM.
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_EZETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL1_WEETH_WETH));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);
        calldata_ = abi.encodeCall(stakedSlipstreamAM.addGauge, (AerodromeGauges.CL200_WETH_DEGEN));
        addToBatch(ArcadiaSafes.OWNER, address(stakedSlipstreamAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
