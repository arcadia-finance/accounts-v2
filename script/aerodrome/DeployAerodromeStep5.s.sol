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
                DeployAddresses.aero_base,
                0,
                DeployRiskConstantsBase.aero_exposure_usdc,
                DeployRiskConstantsBase.aero_collFact_usdc,
                DeployRiskConstantsBase.aero_liqFact_usdc
            )
        );
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                DeployAddresses.aero_base,
                0,
                DeployRiskConstantsBase.aero_exposure_eth,
                DeployRiskConstantsBase.aero_collFact_eth,
                DeployRiskConstantsBase.aero_liqFact_eth
            )
        );
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);

        // Set risk parameters aerodromePoolAM.
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(aerodromePoolAM),
                DeployRiskConstantsBase.aerodromePoolAM_exposure_usdc,
                DeployRiskConstantsBase.aerodromePoolAM_riskFact_usdc
            )
        );
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(aerodromePoolAM),
                DeployRiskConstantsBase.aerodromePoolAM_exposure_eth,
                DeployRiskConstantsBase.aerodromePoolAM_riskFact_eth
            )
        );

        // Set risk parameters slipstreamAM.
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(slipstreamAM),
                DeployRiskConstantsBase.slipstreamAM_exposure_usdc,
                DeployRiskConstantsBase.slipstreamAM_riskFact_usdc
            )
        );
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(slipstreamAM),
                DeployRiskConstantsBase.slipstreamAM_exposure_eth,
                DeployRiskConstantsBase.slipstreamAM_riskFact_eth
            )
        );

        // Set risk parameters stakedAerodromeAM.
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(stakedAerodromeAM),
                DeployRiskConstantsBase.stakedAerodromeAM_exposure_usdc,
                DeployRiskConstantsBase.stakedAerodromeAM_riskFact_usdc
            )
        );
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(stakedAerodromeAM),
                DeployRiskConstantsBase.stakedAerodromeAM_exposure_eth,
                DeployRiskConstantsBase.stakedAerodromeAM_riskFact_eth
            )
        );

        // Set risk parameters wrappedAerodromeAM.
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(wrappedAerodromeAM),
                DeployRiskConstantsBase.wrappedAerodromeAM_exposure_usdc,
                DeployRiskConstantsBase.wrappedAerodromeAM_riskFact_usdc
            )
        );
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(wrappedAerodromeAM),
                DeployRiskConstantsBase.wrappedAerodromeAM_exposure_eth,
                DeployRiskConstantsBase.wrappedAerodromeAM_riskFact_eth
            )
        );
        addToBatch(ArcadiaSafes.riskManager, address(registry), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.riskManager);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
