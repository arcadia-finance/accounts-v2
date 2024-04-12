/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IAeroGauge {
    function deposit(uint256) external;
    function withdraw(uint256) external;
    function rewardToken() external returns (address);
    function earned(address) external view returns (uint256);
    function getReward(address) external;
    function stakingToken() external returns (address);
}
