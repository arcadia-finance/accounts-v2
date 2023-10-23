// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.7.6;
pragma abicoder v2;

import {
    IUniswapV3Factory,
    IUniswapV3Pool,
    NonfungiblePositionManager,
    PoolAddress
} from "../../../../../lib/v3-periphery/contracts/NonfungiblePositionManager.sol";
import { UniswapV3FactoryExtension } from "./UniswapV3FactoryExtension.sol";

contract NonfungiblePositionManagerExtension is NonfungiblePositionManager {
    constructor(address _factory, address _WETH9, address _tokenDescriptor_)
        NonfungiblePositionManager(_factory, _WETH9, _tokenDescriptor_)
    { }

    function createAndInitializePoolIfNecessary(address token0, address token1, uint24 fee, uint160 sqrtPriceX96)
        external
        payable
        override
        returns (address pool)
    {
        require(token0 < token1);
        pool = IUniswapV3Factory(factory).getPool(token0, token1, fee);

        if (pool == address(0)) {
            pool = UniswapV3FactoryExtension(factory).createPoolExtension(token0, token1, fee);
            IUniswapV3Pool(pool).initialize(sqrtPriceX96);
        } else {
            (uint160 sqrtPriceX96Existing,,,,,,) = IUniswapV3Pool(pool).slot0();
            if (sqrtPriceX96Existing == 0) {
                IUniswapV3Pool(pool).initialize(sqrtPriceX96);
            }
        }
    }
}
