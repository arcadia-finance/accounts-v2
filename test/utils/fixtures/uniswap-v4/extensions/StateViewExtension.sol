// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.22;

import { PoolManagerExtension } from "./PoolManagerExtension.sol";
import { StateView } from "../../../../../lib/v4-periphery-fork/src/lens/StateView.sol";

contract StateViewExtension is StateView {
    constructor(PoolManagerExtension poolManager_) StateView(poolManager_) { }
}
