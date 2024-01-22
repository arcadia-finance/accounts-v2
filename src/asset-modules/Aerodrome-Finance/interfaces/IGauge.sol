/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IGauge {
    function deposit(uint256) external;
    function rewardToken() external returns (address);
    function earned(address) external returns (uint256);
    function getReward(address) external;
    function stakingToken() external returns (address);
}
