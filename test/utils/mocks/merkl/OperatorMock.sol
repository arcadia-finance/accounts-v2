/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

contract OperatorMock {
    function onSetMerklOperator(bool operatorStatus, bytes calldata operatorData) external { }
}
