/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

interface IReward {
    /// @notice Add rewards for stakers to earn
    /// @param token    Address of token to reward
    /// @param amount   Amount of token to transfer to rewards
    function notifyRewardAmount(address token, uint256 amount) external;
}
