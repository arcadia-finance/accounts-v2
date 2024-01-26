/**
 * Created by Pragma Labs
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface ISGFactory {
    function getPool(uint256 poolId) external view returns (address);
}
