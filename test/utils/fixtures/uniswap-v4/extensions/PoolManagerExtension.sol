// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import { PoolManager } from "../../../../../lib/v4-periphery-fork/lib/v4-core/src/PoolManager.sol";

contract PoolManagerExtension is PoolManager {
    constructor() PoolManager() { }

    function setCurrentTick(int24 currentTick) public {
        //slot0.tick = currentTick;
    }

    function getCurrentTick() public view returns (int24 currentTick) {
        //currentTick = slot0.tick;
    }

    function setSqrtPriceX96(uint160 sqrtPriceX96_) public {
        //slot0.sqrtPriceX96 = sqrtPriceX96_;
    }
}
