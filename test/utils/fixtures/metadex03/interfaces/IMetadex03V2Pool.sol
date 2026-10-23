// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMetadex03V2Pool {
    function tokens() external view returns (address token0, address token1);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function POOL_TYPE() external view returns (bytes32);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
    function reserve0() external view returns (uint256);
    function reserve1() external view returns (uint256);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256 amountOut);
    function poolFees() external view returns (address);
    function mint(address to) external returns (uint256 liquidity);
    function burn(address to) external returns (uint256 amount0, uint256 amount1);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function sync() external;
    function claimFees(address recipient) external returns (uint256, uint256);
    function pendingFees(address account) external view returns (uint256 amount0, uint256 amount1);
    function index0() external view returns (uint256);
    function index1() external view returns (uint256);
    function supplyIndex0(address account) external view returns (uint256);
    function supplyIndex1(address account) external view returns (uint256);
    function claimable0(address account) external view returns (uint256);
    function claimable1(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function totalSupply() external view returns (uint256);
}
