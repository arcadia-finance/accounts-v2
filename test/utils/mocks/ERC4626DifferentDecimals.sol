// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.19;

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

contract ERC4626DifferentDecimals {
    uint8 public immutable decimals;
    ERC20 public immutable asset;

    constructor(uint8 decimals_, ERC20 asset_) {
        decimals = decimals_;
        asset = asset_;
    }
}
