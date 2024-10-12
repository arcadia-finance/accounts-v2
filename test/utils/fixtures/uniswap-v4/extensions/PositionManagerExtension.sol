// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import { IAllowanceTransfer } from
    "../../../../../lib/v4-periphery-fork/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { PoolKey } from "../../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { PoolManagerExtension } from "./PoolManagerExtension.sol";
import {
    PositionInfo,
    PositionInfoLibrary
} from "../../../../../lib/v4-periphery-fork/src/libraries/PositionInfoLibrary.sol";
import { PositionManager } from "../../../../../lib/v4-periphery-fork/src/PositionManager.sol";

contract PositionManagerExtension is PositionManager {
    using PositionInfoLibrary for PositionInfo;

    constructor(PoolManagerExtension poolManager_, IAllowanceTransfer permit2_, uint256 unsubscribeGasLimit_)
        PositionManager(poolManager_, permit2_, unsubscribeGasLimit_)
    { }

    function setPosition(address receiver, PoolKey memory poolKey, int24 tickLower, int24 tickUpper, uint256 tokenId)
        external
    {
        // mint receipt token
        // tokenId is assigned to current nextTokenId before incrementing it
        _mint(receiver, tokenId);

        // Initialize the position info
        PositionInfo info = PositionInfoLibrary.initialize(poolKey, tickLower, tickUpper);
        positionInfo[tokenId] = info;

        // Init poolKey mapping
        bytes25 poolId = info.poolId();
        poolKeys[poolId] = poolKey;
    }
}
