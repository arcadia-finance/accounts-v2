/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IRegistry {
    /**
     * @notice Adds a new oracle to the Registry.
     * @return oracleId Unique identifier of the oracle.
     */
    function addOracle() external returns (uint256 oracleId);
}
