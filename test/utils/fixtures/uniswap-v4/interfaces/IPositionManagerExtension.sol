// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.30;

import { IPositionManager } from "../../../../../lib/v4-periphery/src/interfaces/IPositionManager.sol";
import { PoolKey } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";

interface IPositionManagerExtension is IPositionManager {
    function setPosition(address receiver, PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint256 tokenId)
        external;
}
