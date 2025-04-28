/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, PrimaryAssets, RiskParameters } from "../utils/ConstantsBase.sol";

contract DeployAerodromeStep9 is Base_Script {
    constructor() { }

    function run() public {
        // Set risk parameters stakedSlipstreamAM.
        bytes memory calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(stakedSlipstreamAM),
                RiskParameters.EXPOSURE_STAKED_SLIPSTREAM_AM_USDC,
                RiskParameters.RISK_FAC_STAKED_SLIPSTREAM_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(stakedSlipstreamAM),
                RiskParameters.EXPOSURE_STAKED_SLIPSTREAM_AM_WETH,
                RiskParameters.RISK_FAC_STAKED_SLIPSTREAM_AM_WETH
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
