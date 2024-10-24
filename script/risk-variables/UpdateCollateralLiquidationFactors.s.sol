/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, PrimaryAssets, RiskParameters } from "../utils/Constants.sol";

contract UpdateRdntExposure is Base_Script {
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
                address(wethLendingPool),
                PrimaryAssets.AERO,
                0,
                RiskParameters.EXPOSURE_AERO_WETH,
                RiskParameters.COL_FAC_AERO_WETH,
                RiskParameters.LIQ_FAC_AERO_WETH
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
                address(usdcLendingPool),
                PrimaryAssets.CBETH,
                0,
                RiskParameters.EXPOSURE_CBETH_USDC,
                RiskParameters.COL_FAC_CBETH_USDC,
                RiskParameters.LIQ_FAC_CBETH_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.CBETH,
                0,
                RiskParameters.EXPOSURE_CBETH_WETH,
                RiskParameters.COL_FAC_CBETH_WETH,
                RiskParameters.LIQ_FAC_CBETH_WETH
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

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.RETH,
                0,
                RiskParameters.EXPOSURE_RETH_USDC,
                RiskParameters.COL_FAC_RETH_USDC,
                RiskParameters.LIQ_FAC_RETH_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.RETH,
                0,
                RiskParameters.EXPOSURE_RETH_WETH,
                RiskParameters.COL_FAC_RETH_WETH,
                RiskParameters.LIQ_FAC_RETH_WETH
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
                address(usdcLendingPool),
                PrimaryAssets.USDBC,
                0,
                RiskParameters.EXPOSURE_USDBC_USDC,
                RiskParameters.COL_FAC_USDBC_USDC,
                RiskParameters.LIQ_FAC_USDBC_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.USDBC,
                0,
                RiskParameters.EXPOSURE_USDBC_WETH,
                RiskParameters.COL_FAC_USDBC_WETH,
                RiskParameters.LIQ_FAC_USDBC_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
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
                address(usdcLendingPool),
                PrimaryAssets.USDT,
                0,
                RiskParameters.EXPOSURE_USDT_USDC,
                RiskParameters.COL_FAC_USDT_USDC,
                RiskParameters.LIQ_FAC_USDT_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.USDT,
                0,
                RiskParameters.EXPOSURE_USDT_WETH,
                RiskParameters.COL_FAC_USDT_WETH,
                RiskParameters.LIQ_FAC_USDT_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

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

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                PrimaryAssets.WSTETH,
                0,
                RiskParameters.EXPOSURE_WSTETH_USDC,
                RiskParameters.COL_FAC_WSTETH_USDC,
                RiskParameters.LIQ_FAC_WSTETH_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.WSTETH,
                0,
                RiskParameters.EXPOSURE_WSTETH_WETH,
                RiskParameters.COL_FAC_WSTETH_WETH,
                RiskParameters.LIQ_FAC_WSTETH_WETH
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
