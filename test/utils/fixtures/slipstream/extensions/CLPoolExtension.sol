// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import { CLPool } from "../../../../../lib/slipstream/contracts/core/CLPool.sol";

contract CLPoolExtension is CLPool {
    constructor() { }

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
