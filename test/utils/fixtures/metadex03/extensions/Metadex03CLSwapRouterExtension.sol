// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import { SwapRouter } from "../../../../../lib/metadex-slipstream/contracts/periphery/SwapRouter.sol";

contract Metadex03CLSwapRouterExtension is SwapRouter {
    constructor(address factory_, address weth9_) SwapRouter(factory_, weth9_) { }
}
