// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

library Hooks {
    uint160 internal constant BEFORE_REMOVE_LIQUIDITY_FLAG = 1 << 9;
    uint160 internal constant AFTER_REMOVE_LIQUIDITY_FLAG = 1 << 8;

    function hasPermission(uint160 hook, uint160 flag) internal pure returns (bool) {
        return hook & flag != 0;
    }
}
