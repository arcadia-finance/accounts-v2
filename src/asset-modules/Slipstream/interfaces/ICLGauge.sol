// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

interface ICLGauge {
    function deposit(uint256 tokenId) external;
    function earned(address account, uint256 tokenId) external view returns (uint256);
    function getReward(uint256 tokenId) external;
    function pool() external returns (address);
    function rewardToken() external returns (address);
    function withdraw(uint256 tokenId) external;
}
