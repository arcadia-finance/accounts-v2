// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import { SwapRouter } from "../../../../../lib/v3-periphery/contracts/SwapRouter.sol";

contract SwapRouterExtension is SwapRouter {
    constructor(address factory_, address WETH9_) SwapRouter(factory_, WETH9_) { }
}
