/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaContracts, ArcadiaSafes, PrimaryAssets, RiskParameters } from "../utils/Constants.sol";

contract UpdateRiskFactors is Base_Script {
    constructor() { }

    function run() public {
        bytes memory calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.USDC,
                0,
                RiskParameters.EXPOSURE_USDC_USDC,
                RiskParameters.COL_FAC_USDC_USDC,
                RiskParameters.LIQ_FAC_USDC_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.USDC,
                0,
                RiskParameters.EXPOSURE_USDC_WETH,
                RiskParameters.COL_FAC_USDC_WETH,
                RiskParameters.LIQ_FAC_USDC_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.WETH,
                0,
                RiskParameters.EXPOSURE_WETH_USDC,
                RiskParameters.COL_FAC_WETH_USDC,
                RiskParameters.LIQ_FAC_WETH_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.WETH,
                0,
                RiskParameters.EXPOSURE_WETH_WETH,
                RiskParameters.COL_FAC_WETH_WETH,
                RiskParameters.LIQ_FAC_WETH_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                ArcadiaContracts.SLIPSTREAM_AM,
                RiskParameters.EXPOSURE_SLIPSTREAM_AM_USDC,
                RiskParameters.RISK_FAC_SLIPSTREAM_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                ArcadiaContracts.SLIPSTREAM_AM,
                RiskParameters.EXPOSURE_SLIPSTREAM_AM_WETH,
                RiskParameters.RISK_FAC_SLIPSTREAM_AM_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                ArcadiaContracts.STAKED_SLIPSTREAM_AM,
                RiskParameters.EXPOSURE_STAKED_SLIPSTREAM_AM_USDC,
                RiskParameters.RISK_FAC_STAKED_SLIPSTREAM_AM_USDC
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
