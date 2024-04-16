/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

interface IVoter {
    /// @notice credibly neutral party similar to Curve's Emergency DAO
    function emergencyCouncil() external view returns (address);

    /// @notice The ve token that governs these contracts
    function ve() external view returns (address);

    /// @dev Gauge => Liveness status
    function isAlive(address gauge) external view returns (bool);
}
