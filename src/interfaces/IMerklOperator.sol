/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

interface IMerklOperator {
    function onToggleMerklOperator(bytes calldata operatorData) external view returns (uint256);
}
