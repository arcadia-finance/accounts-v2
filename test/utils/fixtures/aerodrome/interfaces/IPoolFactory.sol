/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

interface IPoolFactory {
    /// @notice Returns fee for a pool, as custom fees are possible.
    function getFee(address _pool, bool _stable) external view returns (uint256);

    function isPaused() external view returns (bool);

    function voter() external view returns (address);
}
