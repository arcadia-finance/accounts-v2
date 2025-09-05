/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Claim, Distributor } from "../../../../../lib/merkl-contracts/contracts/Distributor.sol";

contract DistributorExtension is Distributor {
    function setClaimed(address user, address token, uint208 amount) external {
        setClaimed(user, token, amount, uint48(block.timestamp), getMerkleRoot());
    }

    function setClaimed(address user, address token, uint208 amount, uint48 timestamp, bytes32 merkleRoot) public {
        claimed[user][token] = Claim(amount, timestamp, merkleRoot);
    }
}
