// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import { PoolKey } from "../../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import { PositionInfo } from "../../../../lib/v4-periphery/src/libraries/PositionInfoLibrary.sol";

/// @title Non-fungible token for positions
/// @notice Wraps Uniswap V4 positions in a non-fungible token interface which allows for them to be transferred
/// and authorized.
interface IPositionManager {
    function poolManager() external view returns (address poolManager_);
    function getPoolAndPositionInfo(uint256 id) external view returns (PoolKey memory poolKey, PositionInfo info);
}
