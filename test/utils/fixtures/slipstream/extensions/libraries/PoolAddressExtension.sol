// https://github.com/velodrome-finance/slipstream/blob/main/contracts/periphery/libraries/PoolAddress.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.22;

import { PoolAddress } from "../../../../../../src/asset-modules/Slipstream/libraries/PoolAddress.sol";

/// @title Provides functions for deriving a pool address from the factory, tokens, and the tickSpacing
library PoolAddressExtension {
    /// @notice Returns PoolKey: the ordered tokens with the matched tickSpacing
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param tickSpacing The tick spacing of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(address tokenA, address tokenB, int24 tickSpacing)
        internal
        pure
        returns (PoolAddress.PoolKey memory)
    {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolAddress.PoolKey({ token0: tokenA, token1: tokenB, tickSpacing: tickSpacing });
    }
}
