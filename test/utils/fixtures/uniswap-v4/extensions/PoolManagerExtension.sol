// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import { Pool } from "../../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/Pool.sol";
import { PoolId } from "../../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolId.sol";
import { PoolManager } from "../../../../../lib/v4-periphery-fork/lib/v4-core/src/PoolManager.sol";
import { Position } from "../../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/Position.sol";

contract PoolManagerExtension is PoolManager {
    constructor() PoolManager() { }

    function setPositionLiquidity(PoolId poolId, bytes32 positionKey, uint128 liquidity) public {
        Pool.State storage poolState = _getPool(poolId);
        Position.State storage position = poolState.positions[positionKey];
        position.liquidity = liquidity;
    }

    function getTickSpacingToMaxLiquidityPerTick(int24 tickSpacing) public pure returns (uint128 result) {
        result = Pool.tickSpacingToMaxLiquidityPerTick(tickSpacing);
    }
}
