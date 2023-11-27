/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

/// @notice Abstract contract containing all the errors emitted by the protocol.
abstract contract Errors {
    error FunctionIsPaused();
    error FunctionNotImplemented();
    error OpenPositionNonZero();
}
