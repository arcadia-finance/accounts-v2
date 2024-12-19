/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Script } from "../../Base.s.sol";

import { AccountLogic, ArcadiaSafes, MerkleRoots } from "../../utils/Constants.sol";

contract AddSpotAccountsStep2 is Base_Script {
    constructor() { }

    function run() public {
        // Add Chainlink oracles.
        bytes memory calldata_ =
            abi.encodeCall(factory.setNewAccountInfo, (address(registry), AccountLogic.V2, MerkleRoots.V2, ""));
        addToBatch(ArcadiaSafes.OWNER, address(factory), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
