// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool);

    function feeAmountTickSpacing(uint24 fee) external view returns (int24 tickSpacing);

    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}
