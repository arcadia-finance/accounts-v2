// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IUniswapV3Pool } from "../../src/pricing-modules/UniswapV3/interfaces/IUniswapV3Pool.sol";
import { INonfungiblePositionManager } from
    "../../src/pricing-modules/UniswapV3/interfaces/INonfungiblePositionManager.sol";

interface IUniswapV3PoolExtension is IUniswapV3Pool {
    function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;

    function maxLiquidityPerTick() external view returns (uint128 maxLiquidityPerTick);

    function token0() external view returns (address token0);

    function token1() external view returns (address token1);

    function fee() external view returns (uint24 fee);
}

interface INonfungiblePositionManagerExtension is INonfungiblePositionManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        returns (address pool);

    function mint(MintParams calldata params)
        external
        returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        returns (uint256 amount0, uint256 amount1);
}
