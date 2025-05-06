/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, PrimaryAssets, RiskParameters } from "../utils/Constants.sol";

contract DeployAerodromeStep5 is Base_Script {
    constructor() { }

    function run() public {
        // Set risk parameters Aero.
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

        // Set risk parameters aerodromePoolAM.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(aerodromePoolAM),
                RiskParameters.EXPOSURE_AERO_POOL_AM_USDC,
                RiskParameters.RISK_FAC_AERO_POOL_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(aerodromePoolAM),
                RiskParameters.EXPOSURE_AERO_POOL_AM_WETH,
                RiskParameters.RISK_FAC_AERO_POOL_AM_WETH
            )
        );

        // Set risk parameters slipstreamAM.
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(slipstreamAM),
                RiskParameters.EXPOSURE_SLIPSTREAM_AM_USDC,
                RiskParameters.RISK_FAC_SLIPSTREAM_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(slipstreamAM),
                RiskParameters.EXPOSURE_SLIPSTREAM_AM_WETH,
                RiskParameters.RISK_FAC_SLIPSTREAM_AM_WETH
            )
        );

        // Set risk parameters stakedAerodromeAM.
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(stakedAerodromeAM),
                RiskParameters.EXPOSURE_STAKED_AERO_AM_USDC,
                RiskParameters.RISK_FAC_STAKED_AERO_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(stakedAerodromeAM),
                RiskParameters.EXPOSURE_STAKED_AERO_AM_WETH,
                RiskParameters.RISK_FAC_STAKED_AERO_AM_WETH
            )
        );

        // Set risk parameters wrappedAerodromeAM.
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(wrappedAerodromeAM),
                RiskParameters.EXPOSURE_WRAPPED_AERO_AM_USDC,
                RiskParameters.RISK_FAC_WRAPPED_AERO_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(wrappedAerodromeAM),
                RiskParameters.EXPOSURE_WRAPPED_AERO_AM_WETH,
                RiskParameters.RISK_FAC_WRAPPED_AERO_AM_WETH
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
