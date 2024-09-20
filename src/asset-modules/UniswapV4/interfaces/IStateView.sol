// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.22;

import { PoolId } from "../../../../lib/v4_periphery/lib/v4-core/src/types/PoolId.sol";

interface IStateView {
    function getPositionLiquidity(PoolId poolId, bytes32 positionId) external view returns (uint128 liquidity);
    function getFeeGrowthInside(PoolId poolId, int24 tickLower, int24 tickUpper)
        external
        view
        returns (uint256 feeGrowthInside0CurrentX128, uint256 feeGrowthInside1CurrentX128);
    function getPositionInfo(PoolId poolId, bytes32 positionId)
        external
        view
        returns (uint128 liqudity, uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128);
}
