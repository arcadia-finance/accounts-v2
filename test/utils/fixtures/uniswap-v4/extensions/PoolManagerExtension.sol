// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.26;

import { Pool } from "../../../../../lib/v4-periphery/lib/v4-core/src/libraries/Pool.sol";
import { PoolId } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";
import { PoolManager } from "../../../../../lib/v4-periphery/lib/v4-core/src/PoolManager.sol";
import { Position } from "../../../../../lib/v4-periphery/lib/v4-core/src/libraries/Position.sol";
import { Slot0 } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/Slot0.sol";

contract PoolManagerExtension is PoolManager {
    constructor() PoolManager(msg.sender) { }

    function setPositionLiquidity(PoolId poolId, bytes32 positionKey, uint128 liquidity) public {
        Pool.State storage poolState = _getPool(poolId);
        Position.State storage position = poolState.positions[positionKey];
        position.liquidity = liquidity;
    }

    function setCurrentPrice(PoolId poolId, int24 tick, uint160 sqrtPriceX96) public {
        Pool.State storage poolState = _getPool(poolId);
        Slot0 currentSlot0 = poolState.slot0;
        Slot0 updatedSlot0 = currentSlot0.setTick(tick).setSqrtPriceX96(sqrtPriceX96);
        poolState.slot0 = updatedSlot0;
    }

    function setFeeGrowthInsideLast(
        PoolId poolId,
        bytes32 positionKey,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128
    ) public {
        Pool.State storage poolState = _getPool(poolId);
        Position.State storage position = poolState.positions[positionKey];
        position.feeGrowthInside0LastX128 = feeGrowthInside0LastX128;
        position.feeGrowthInside1LastX128 = feeGrowthInside1LastX128;
    }

    function setFeeGrowthOutside(
        PoolId poolId,
        int24 tickLower,
        int24 tickUpper,
        uint256 lowerFeeGrowthOutside0X128,
        uint256 upperFeeGrowthOutside0X128,
        uint256 lowerFeeGrowthOutside1X128,
        uint256 upperFeeGrowthOutside1X128
    ) public {
        Pool.State storage poolState = _getPool(poolId);
        Pool.TickInfo storage tickLower_ = poolState.ticks[tickLower];
        Pool.TickInfo storage tickUpper_ = poolState.ticks[tickUpper];

        tickLower_.feeGrowthOutside0X128 = lowerFeeGrowthOutside0X128;
        tickLower_.feeGrowthOutside1X128 = lowerFeeGrowthOutside1X128;

        tickUpper_.feeGrowthOutside0X128 = upperFeeGrowthOutside0X128;
        tickUpper_.feeGrowthOutside1X128 = upperFeeGrowthOutside1X128;
    }

    function setFeeGrowthGlobal(PoolId poolId, uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128) public {
        Pool.State storage poolState = _getPool(poolId);
        poolState.feeGrowthGlobal0X128 = feeGrowthGlobal0X128;
        poolState.feeGrowthGlobal1X128 = feeGrowthGlobal1X128;
    }

    function getTickSpacingToMaxLiquidityPerTick(int24 tickSpacing) public pure returns (uint128 result) {
        result = Pool.tickSpacingToMaxLiquidityPerTick(tickSpacing);
    }
}
