// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.22;

interface ICLPool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            bool unlocked
        );

    function ticks(int24 tick)
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            int128 stakedLiquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            uint128 rewardGrowthOutsideX128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    function feeGrowthGlobal0X128() external view returns (uint256 feeGrowthGlobal0X128);

    function feeGrowthGlobal1X128() external view returns (uint256 feeGrowthGlobal1X128);
}
