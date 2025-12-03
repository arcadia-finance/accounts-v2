// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ICLFactory } from "../../../../../../src/asset-modules/Slipstream/interfaces/ICLFactory.sol";

interface ICLFactoryExtension is ICLFactory {
    function getPool(address tokenA, address tokenB, int24 tickSpacing) external view returns (address pool);

    function createPool(address tokenA, address tokenB, int24 tickSpacing, uint160 sqrtPriceX96)
        external
        returns (address pool);
}
