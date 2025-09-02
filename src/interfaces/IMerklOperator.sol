/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

interface IMerklOperator {
    function onSetMerklOperator(address accountOwner, bool status, bytes calldata data) external;
}
