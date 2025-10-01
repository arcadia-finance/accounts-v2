/**
 * Created by Pragma Labs
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

interface ISGFactory {
    function getPool(uint256 poolId) external view returns (address);
}
