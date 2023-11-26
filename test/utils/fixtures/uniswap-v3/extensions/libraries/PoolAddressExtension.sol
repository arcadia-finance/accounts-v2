// https://github.com/Uniswap/v3-periphery/blob/main/contracts/libraries/PoolAddress.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.22;

import { PoolAddress } from "../../../../../../src/asset-modules/UniswapV3/libraries/PoolAddress.sol";

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddressExtension {
    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(address tokenA, address tokenB, uint24 fee)
        internal
        pure
        returns (PoolAddress.PoolKey memory)
    {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolAddress.PoolKey({ token0: tokenA, token1: tokenB, fee: fee });
    }
}
