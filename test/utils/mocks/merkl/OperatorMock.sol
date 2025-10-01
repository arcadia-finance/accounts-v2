/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { IMerklOperator } from "../../../../src/interfaces/IMerklOperator.sol";

contract OperatorMock is IMerklOperator {
    function onSetMerklOperator(address accountOwner, bool status, bytes calldata data) external { }
}
