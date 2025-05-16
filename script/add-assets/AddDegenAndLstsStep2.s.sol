/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, PrimaryAssets, RiskParameters } from "../utils/ConstantsBase.sol";

contract AddDegenAndLstsStep2 is Base_Script {
    constructor() { }

    function run() public {
        // DEGEN
        bytes memory calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.DEGEN,
                0,
                RiskParameters.EXPOSURE_DEGEN_USDC,
                RiskParameters.COL_FAC_DEGEN_USDC,
                RiskParameters.LIQ_FAC_DEGEN_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.DEGEN,
                0,
                RiskParameters.EXPOSURE_DEGEN_WETH,
                RiskParameters.COL_FAC_DEGEN_WETH,
                RiskParameters.LIQ_FAC_DEGEN_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // ezETH
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.EZETH,
                0,
                RiskParameters.EXPOSURE_EZETH_USDC,
                RiskParameters.COL_FAC_EZETH_USDC,
                RiskParameters.LIQ_FAC_EZETH_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.EZETH,
                0,
                RiskParameters.EXPOSURE_EZETH_WETH,
                RiskParameters.COL_FAC_EZETH_WETH,
                RiskParameters.LIQ_FAC_EZETH_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // weETH
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.WEETH,
                0,
                RiskParameters.EXPOSURE_WEETH_USDC,
                RiskParameters.COL_FAC_WEETH_USDC,
                RiskParameters.LIQ_FAC_WEETH_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.WEETH,
                0,
                RiskParameters.EXPOSURE_WEETH_WETH,
                RiskParameters.COL_FAC_WEETH_WETH,
                RiskParameters.LIQ_FAC_WEETH_WETH
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
