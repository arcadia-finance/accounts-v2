/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaContracts, ArcadiaSafes, RiskParameters } from "../utils/ConstantsBase.sol";
import { DefaultUniswapV4AM } from "../../src/asset-modules/UniswapV4/DefaultUniswapV4AM.sol";
import { UniswapV4HooksRegistry } from "../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

contract DeployUniswapV4Step2 is Base_Script {
    DefaultUniswapV4AM internal defaultUniswapV4AM = DefaultUniswapV4AM(ArcadiaContracts.DEFAULT_UNISWAPV4_AM);
    UniswapV4HooksRegistry internal uniswapV4HooksRegistry =
        UniswapV4HooksRegistry(ArcadiaContracts.UNISWAPV4_HOOKS_REGISTRY);

    constructor() { }

    function run() public {
        bytes memory calldata_ = abi.encodeCall(registry.addAssetModule, (address(uniswapV4HooksRegistry)));
        addToBatch(ArcadiaSafes.OWNER, address(registry), calldata_);

        calldata_ = abi.encodeCall(uniswapV4HooksRegistry.setProtocol, ());
        addToBatch(ArcadiaSafes.OWNER, address(uniswapV4HooksRegistry), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));

        calldata_ = abi.encodeCall(
            uniswapV4HooksRegistry.setRiskParametersOfDerivedAM,
            (
                address(cbbtcLendingPool),
                address(defaultUniswapV4AM),
                RiskParameters.EXPOSURE_DEFAULT_UNISWAPV4_AM_CBBTC,
                RiskParameters.RISK_FAC_DEFAULT_UNISWAPV4_AM_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(uniswapV4HooksRegistry), calldata_);
        calldata_ = abi.encodeCall(
            uniswapV4HooksRegistry.setRiskParametersOfDerivedAM,
            (
                address(usdcLendingPool),
                address(defaultUniswapV4AM),
                RiskParameters.EXPOSURE_DEFAULT_UNISWAPV4_AM_USDC,
                RiskParameters.RISK_FAC_DEFAULT_UNISWAPV4_AM_USDC
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(uniswapV4HooksRegistry), calldata_);
        calldata_ = abi.encodeCall(
            uniswapV4HooksRegistry.setRiskParametersOfDerivedAM,
            (
                address(wethLendingPool),
                address(defaultUniswapV4AM),
                RiskParameters.EXPOSURE_DEFAULT_UNISWAPV4_AM_WETH,
                RiskParameters.RISK_FAC_DEFAULT_UNISWAPV4_AM_WETH
            )
        );
        addToBatch(ArcadiaSafes.RISK_MANAGER, address(uniswapV4HooksRegistry), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        data = createBatchedData(ArcadiaSafes.RISK_MANAGER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
