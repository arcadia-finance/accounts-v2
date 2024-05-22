/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

struct Rewards {
    address market;
    address rewardToken;
    uint256 supplyRewardsAmount;
    uint256 borrowRewardsAmount;
}

interface IMoonwellViews {
    /// @notice Function to get the user accrued and pendings rewards
    function getUserRewards(address _user) external view returns (Rewards[] memory);
}
