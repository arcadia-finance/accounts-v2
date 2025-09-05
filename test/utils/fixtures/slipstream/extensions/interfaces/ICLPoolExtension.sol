// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ICLPool } from "../../../../../../src/asset-modules/Slipstream/interfaces/ICLPool.sol";

interface ICLPoolExtension is ICLPool {
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;

    function maxLiquidityPerTick() external view returns (uint128 maxLiquidityPerTick);

    function rewardGrowthGlobalX128() external view returns (uint256 rewardGrowthGlobalX128_);

    function rewardReserve() external view returns (uint256 rewardReserve_);

    function token0() external view returns (address token0);

    function token1() external view returns (address token1);

    function tickSpacing() external view returns (int24 tickSpacing);

    function setCurrentTick(int24 currentTick) external;

    function getCurrentTick() external returns (int24 currentTick);

    function setSqrtPriceX96(uint160 sqrtPriceX96_) external;

    function liquidity() external returns (uint128 liquidity);

    function fee() external view returns (uint24);
}
