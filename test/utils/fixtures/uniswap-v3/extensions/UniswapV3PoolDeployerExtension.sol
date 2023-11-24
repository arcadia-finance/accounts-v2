// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;

import { UniswapV3PoolDeployer } from "@uniswap/v3-core/contracts/UniswapV3PoolDeployer.sol";
import { UniswapV3PoolExtension } from "./UniswapV3PoolExtension.sol";

contract UniswapV3PoolDeployerExtension is UniswapV3PoolDeployer {
    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The spacing between usable ticks
    function deployExtension(address factory, address token0, address token1, uint24 fee, int24 tickSpacing)
        internal
        returns (address pool)
    {
        parameters =
            Parameters({ factory: factory, token0: token0, token1: token1, fee: fee, tickSpacing: tickSpacing });
        pool = address(new UniswapV3PoolExtension{ salt: keccak256(abi.encode(token0, token1, fee)) }());
        delete parameters;
    }
}
