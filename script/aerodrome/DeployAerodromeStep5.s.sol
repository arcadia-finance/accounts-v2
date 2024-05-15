/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, DeployAddresses, DeployRiskConstantsBase } from "../utils/Constants.sol";

contract DeployAerodromeStep5 is Base_Script {
    constructor() { }

    function run() public {
        // Set risk parameters Aero.
        bytes memory calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(usdcLendingPool),
                DeployAddresses.AERO,
                0,
                DeployRiskConstantsBase.EXPOSURE_AERO_USDC,
                DeployRiskConstantsBase.COL_FAC_AERO_USDC,
                DeployRiskConstantsBase.LIQ_FAC_AERO_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                DeployAddresses.AERO,
                0,
                DeployRiskConstantsBase.EXPOSURE_AERO_WETH,
                DeployRiskConstantsBase.COL_FAC_AERO_WETH,
                DeployRiskConstantsBase.LIQ_FAC_AERO_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // Set risk parameters aerodromePoolAM.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(aerodromePoolAM),
                DeployRiskConstantsBase.EXPOSURE_AERO_POOL_AM_USDC,
                DeployRiskConstantsBase.RISK_FAC_AERO_POOL_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(aerodromePoolAM),
                DeployRiskConstantsBase.EXPOSURE_AERO_POOL_AM_WETH,
                DeployRiskConstantsBase.RISK_FAC_AERO_POOL_AM_WETH
            )
        );

        // Set risk parameters slipstreamAM.
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(slipstreamAM),
                DeployRiskConstantsBase.EXPOSURE_SLIPSTREAM_USDC,
                DeployRiskConstantsBase.RISK_FAC_SLIPSTREAM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(slipstreamAM),
                DeployRiskConstantsBase.EXPOSURE_SLIPSTREAM_WETH,
                DeployRiskConstantsBase.RISK_FAC_SLIPSTREAM_WETH
            )
        );

        // Set risk parameters stakedAerodromeAM.
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(stakedAerodromeAM),
                DeployRiskConstantsBase.EXPOSURE_STAKED_AERO_AM_USDC,
                DeployRiskConstantsBase.RISK_FAC_STAKED_AERO_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(stakedAerodromeAM),
                DeployRiskConstantsBase.EXPOSURE_STAKED_AERO_AM_WETH,
                DeployRiskConstantsBase.RISK_FAC_STAKED_AERO_AM_WETH
            )
        );

        // Set risk parameters wrappedAerodromeAM.
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(wrappedAerodromeAM),
                DeployRiskConstantsBase.EXPOSURE_WRAPPED_AERO_AM_USDC,
                DeployRiskConstantsBase.RISK_FAC_WRAPPED_AERO_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(wrappedAerodromeAM),
                DeployRiskConstantsBase.EXPOSURE_WRAPPED_AERO_AM_WETH,
                DeployRiskConstantsBase.RISK_FAC_WRAPPED_AERO_AM_WETH
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
