// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { ICLPool } from "../../../../../../src/asset-modules/Slipstream/interfaces/ICLPool.sol";

interface ICLPoolExtension is ICLPool {
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;

    function maxLiquidityPerTick() external view returns (uint128 maxLiquidityPerTick);

    function token0() external view returns (address token0);

    function token1() external view returns (address token1);

    function tickSpacing() external view returns (int24 tickSpacing);
}
