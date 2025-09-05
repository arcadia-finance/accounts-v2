/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountLogic } from "../utils/constants/Shared.sol";
import { Base_Script } from "../Base.s.sol";
import { MerkleRoots, Safes } from "../utils/constants/Base.sol";
import { Utils } from "../../test/utils/Utils.sol";

contract AddAccountImplementationsStep2 is Base_Script {
    address internal SAFE = Safes.OWNER;

    function run() public {
        bytes32 leaf0 = keccak256(abi.encodePacked(uint256(1), uint256(3)));
        bytes32 leaf1 = keccak256(abi.encodePacked(uint256(2), uint256(4)));
        bytes32 root = Utils.commutativeKeccak256(leaf0, leaf1);
        emit log_bytes32(root);

        // Add New Account Implementations.
        addToBatch(
            SAFE,
            address(factory),
            abi.encodeCall(factory.setNewAccountInfo, (address(registry), AccountLogic.V3, root, ""))
        );
        addToBatch(
            SAFE,
            address(factory),
            abi.encodeCall(factory.setNewAccountInfo, (address(registry), AccountLogic.V4, root, ""))
        );

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
