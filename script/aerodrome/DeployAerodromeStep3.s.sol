/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes, DeployAddresses } from "../utils/Constants.sol";

contract DeployAerodromeStep3 is Base_Script {
    constructor() { }

    function run() public {
        // Add Asset Modules to Registry.
        bytes memory calldata_ = abi.encodeCall(registry.addAssetModule, (address(aerodromePoolAM)));
        addToBatch(ArcadiaSafes.owner, address(registry), calldata_);

        calldata_ = abi.encodeCall(registry.addAssetModule, (address(slipstreamAM)));
        addToBatch(ArcadiaSafes.owner, address(registry), calldata_);

        calldata_ = abi.encodeCall(registry.addAssetModule, (address(stakedAerodromeAM)));
        addToBatch(ArcadiaSafes.owner, address(registry), calldata_);

        calldata_ = abi.encodeCall(registry.addAssetModule, (address(wrappedAerodromeAM)));
        addToBatch(ArcadiaSafes.owner, address(registry), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.owner);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
