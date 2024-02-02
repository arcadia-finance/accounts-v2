/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

contract AerodromeGaugeMock {
    address public rewardToken;
    address public stakingToken;

    function setRewardToken(address rewardToken_) public {
        rewardToken = rewardToken_;
    }

    function setStakingToken(address stakingToken_) public {
        stakingToken = stakingToken_;
    }
}
