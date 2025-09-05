// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IAllowanceTransfer } from "../../../../../lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { IPoolManager } from "../../../../../lib/v4-periphery/lib/v4-core/src/interfaces/IPoolManager.sol";
import { IPositionDescriptor } from "../../../../../lib/v4-periphery/src/interfaces/IPositionDescriptor.sol";
import { IWETH9 } from "../../../../../lib/v4-periphery/src/interfaces/external/IWETH9.sol";
import { PoolKey } from "../../../../../lib/v4-periphery/lib/v4-core/src/types/PoolKey.sol";
import {
    PositionInfo, PositionInfoLibrary
} from "../../../../../lib/v4-periphery/src/libraries/PositionInfoLibrary.sol";
import { PositionManager } from "../../../../../lib/v4-periphery/src/PositionManager.sol";

contract PositionManagerExtension is PositionManager {
    using PositionInfoLibrary for PositionInfo;

    constructor(
        IPoolManager poolManager_,
        IAllowanceTransfer permit2_,
        uint256 unsubscribeGasLimit_,
        IPositionDescriptor tokenDescriptor_,
        IWETH9 weth9_
    ) PositionManager(poolManager_, permit2_, unsubscribeGasLimit_, tokenDescriptor_, weth9_) { }

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
