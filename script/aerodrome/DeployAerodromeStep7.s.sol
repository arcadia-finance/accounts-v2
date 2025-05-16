/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Script } from "../Base.s.sol";

import { ArcadiaSafes } from "../utils/ConstantsBase.sol";

contract DeployAerodromeStep7 is Base_Script {
    constructor() { }

    function run() public {
        // Add Asset Modules to Registry.
        bytes memory calldata_ = abi.encodeCall(registry.addAssetModule, (address(stakedSlipstreamAM)));
        addToBatch(ArcadiaSafes.OWNER, address(registry), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
