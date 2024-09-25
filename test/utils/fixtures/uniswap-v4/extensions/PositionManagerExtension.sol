// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import { IAllowanceTransfer } from
    "../../../../../lib/v4-periphery-fork/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import { PoolManagerExtension } from "./PoolManagerExtension.sol";
import { PositionManager } from "../../../../../lib/v4-periphery-fork/src/PositionManager.sol";

contract PositionManagerExtension is PositionManager {
    constructor(PoolManagerExtension poolManager_, IAllowanceTransfer permit2_, uint256 unsubscribeGasLimit_)
        PositionManager(poolManager_, permit2_, unsubscribeGasLimit_)
    { }
}
