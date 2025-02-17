/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, PrimaryAssets, RiskParameters } from "../utils/Constants.sol";

contract UpdateRiskFactors is Base_Script {
    constructor() { }

    function run() public {
        bytes memory calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.AERO,
                0,
                RiskParameters.EXPOSURE_AERO_USDC,
                RiskParameters.COL_FAC_AERO_USDC,
                RiskParameters.LIQ_FAC_AERO_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
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
                address(wethLendingPool),
                PrimaryAssets.CBBTC,
                0,
                RiskParameters.EXPOSURE_CBBTC_WETH,
                RiskParameters.COL_FAC_CBBTC_WETH,
                RiskParameters.LIQ_FAC_CBBTC_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.DAI,
                0,
                RiskParameters.EXPOSURE_DAI_USDC,
                RiskParameters.COL_FAC_DAI_USDC,
                RiskParameters.LIQ_FAC_DAI_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.DAI,
                0,
                RiskParameters.EXPOSURE_DAI_WETH,
                RiskParameters.COL_FAC_DAI_WETH,
                RiskParameters.LIQ_FAC_DAI_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
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
        bytes memory data = createBatchedData(ArcadiaSafes.RISK_MANAGER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
