// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import { UniswapV3Pool } from "@uniswap/v3-core/contracts/UniswapV3Pool.sol";

contract UniswapV3PoolExtension is UniswapV3Pool {
    constructor() UniswapV3Pool() { }
}
