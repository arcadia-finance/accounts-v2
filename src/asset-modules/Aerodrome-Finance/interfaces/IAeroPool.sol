/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IAeroPool {
    function index0() external view returns (uint256);
    function index1() external view returns (uint256);
    function supplyIndex0(address) external view returns (uint256);
    function supplyIndex1(address) external view returns (uint256);
    function claimable0(address) external view returns (uint256);
    function claimable1(address) external view returns (uint256);
    function tokens() external view returns (address token0, address token1);
    function getK() external view returns (uint256);
    function claimFees() external returns (uint256, uint256);
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1, uint256 blockTimestampLast);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function stable() external returns (bool);
}
