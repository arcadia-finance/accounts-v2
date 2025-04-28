/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, RiskParameters } from "../utils/ConstantsBase.sol";

contract DeployAlienBaseStep2 is Base_Script {
    constructor() { }

    function run() public {
        bytes memory calldata_ = abi.encodeCall(registry.addAssetModule, (address(alienBaseAM)));
        addToBatch(ArcadiaSafes.OWNER, address(registry), calldata_);

        calldata_ = abi.encodeCall(alienBaseAM.setProtocol, ());
        addToBatch(ArcadiaSafes.OWNER, address(alienBaseAM), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));

        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(cbbtcLendingPool),
                address(alienBaseAM),
                RiskParameters.EXPOSURE_ALIEN_BASE_AM_CBBTC,
                RiskParameters.RISK_FAC_ALIEN_BASE_AM_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(alienBaseAM),
                RiskParameters.EXPOSURE_ALIEN_BASE_AM_USDC,
                RiskParameters.RISK_FAC_ALIEN_BASE_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(alienBaseAM),
                RiskParameters.EXPOSURE_ALIEN_BASE_AM_WETH,
                RiskParameters.RISK_FAC_ALIEN_BASE_AM_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(registry), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        data = createBatchedData(ArcadiaSafes.RISK_MANAGER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
