/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IERC20 {
    function decimals() external view returns (uint256);
    function balanceOf(address) external returns (uint256);
}
