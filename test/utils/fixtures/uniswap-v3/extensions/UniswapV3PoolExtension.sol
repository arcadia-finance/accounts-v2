// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import { UniswapV3Pool } from "@uniswap/v3-core/contracts/UniswapV3Pool.sol";

contract UniswapV3PoolExtension is UniswapV3Pool {
    constructor() UniswapV3Pool() { }

    function setCurrentTick(int24 currentTick) public {
        slot0.tick = currentTick;
    }

    function getCurrentTick() public view returns (int24 currentTick) {
        currentTick = slot0.tick;
    }

    function setSqrtPriceX96(uint160 sqrtPriceX96_) public {
        slot0.sqrtPriceX96 = sqrtPriceX96_;
    }
}
