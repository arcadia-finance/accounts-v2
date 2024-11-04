/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import {
    AerodromeGauges,
    ArcadiaContracts,
    ArcadiaSafes,
    CutOffTimes,
    OracleIds,
    Oracles,
    PrimaryAssets,
    RiskParameters
} from "../utils/Constants.sol";

contract UpdateWETHExposure is Base_Script {
    constructor() { }

    function run() public {
        bytes memory calldata_ = abi.encodeCall(
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

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.RISK_MANAGER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
