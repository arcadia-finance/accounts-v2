// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {
    NonfungiblePositionManager
} from "../../../../../lib/slipstream/contracts/periphery/NonfungiblePositionManager.sol";

contract SlipstreamNonfungiblePositionManagerExtension is NonfungiblePositionManager {
    constructor(
        address owner_,
        address factory_,
        address weth9_,
        address tokenDescriptor_,
        string memory name_,
        string memory symbol_
    ) NonfungiblePositionManager(owner_, factory_, weth9_, tokenDescriptor_, name_, symbol_) { }
}
