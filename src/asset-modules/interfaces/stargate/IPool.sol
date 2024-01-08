/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IPool {
    function token() external view returns (address);
    function totalLiquidity() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function convertRate() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}
