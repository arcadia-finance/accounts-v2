// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { IPoolManager } from "../../../../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import { PoolId } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/PoolId.sol";

interface IPoolManagerExtension is IPoolManager {
    function getTickSpacingToMaxLiquidityPerTick(int24 tickSpacing) external pure returns (uint128 result);
    function setCurrentPrice(PoolId poolId, int24 tick, uint160 sqrtPriceX96) external;
    function setFeeGrowthGlobal(PoolId poolId, uint256 feeGrowthGlobal0X128, uint256 feeGrowthGlobal1X128) external;
    function setFeeGrowthInsideLast(
        PoolId poolId,
        bytes32 positionKey,
        uint256 feeGrowthInside0LastX128,
        uint256 feeGrowthInside1LastX128
    ) external;
    function setFeeGrowthOutside(
        PoolId poolId,
        int24 tickLower,
        int24 tickUpper,
        uint256 lowerFeeGrowthOutside0X128,
        uint256 upperFeeGrowthOutside0X128,
        uint256 lowerFeeGrowthOutside1X128,
        uint256 upperFeeGrowthOutside1X128
    ) external;
    function setPositionLiquidity(PoolId poolId, bytes32 positionKey, uint128 liquidity) external;
}
