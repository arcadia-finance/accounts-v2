/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface IOracleHub {
    /**
     * @notice Adds a new oracle to the Oracle Hub.
     */
    function addOracle() external returns (uint256 oracleCounter_);
}
