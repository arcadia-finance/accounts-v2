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
                address(usdcLendingPool),
                PrimaryAssets.USDS,
                0,
                RiskParameters.EXPOSURE_USDS_USDC,
                RiskParameters.COL_FAC_USDS_USDC,
                RiskParameters.LIQ_FAC_USDS_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (
                address(wethLendingPool),
                PrimaryAssets.USDS,
                0,
                RiskParameters.EXPOSURE_USDS_WETH,
                RiskParameters.COL_FAC_USDS_WETH,
                RiskParameters.LIQ_FAC_USDS_WETH
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
