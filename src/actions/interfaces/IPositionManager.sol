// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.22;

/// @title Non-fungible token for positions of Uniswap V4
interface IPositionManager {
    function nextTokenId() external view returns (uint256);
}
