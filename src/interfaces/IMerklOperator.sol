/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

interface IMerklOperator {
    function onSetMerklOperator(bool operatorStatus, bytes calldata operatorData) external;
}
