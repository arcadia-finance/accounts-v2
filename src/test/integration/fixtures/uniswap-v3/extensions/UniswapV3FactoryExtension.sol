// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import { UniswapV3Factory } from "@uniswap/v3-core/contracts/UniswapV3Factory.sol";
import { UniswapV3PoolDeployerExtension } from "./UniswapV3PoolDeployerExtension.sol";

contract UniswapV3FactoryExtension is UniswapV3Factory, UniswapV3PoolDeployerExtension {
    constructor() UniswapV3Factory() { }

    function createPoolExtension(address tokenA, address tokenB, uint24 fee)
        external
        noDelegateCall
        returns (address pool)
    {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        int24 tickSpacing = feeAmountTickSpacing[fee];
        require(tickSpacing != 0);
        require(getPool[token0][token1][fee] == address(0));
        pool = deployExtension(address(this), token0, token1, fee, tickSpacing);
        getPool[token0][token1][fee] = pool;
        // populate mapping in the reverse direction, deliberate choice to avoid the cost of comparing addresses
        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }
}
