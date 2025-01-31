/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, PrimaryAssets, RiskParameters } from "../utils/Constants.sol";

contract UpdateExposure is Base_Script {
    constructor() { }

    function run() public {
        bytes memory calldata_ = abi.encodeCall(
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

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.RISK_MANAGER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
