/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

// interfaces
import { IERC20 } from "../../../../src/interfaces/IERC20.sol";

contract AerodromeGaugeMock {
    address public stakingToken;
    address public rewardToken;
    mapping(address => uint256) public earned;

    function setEarnedForAddress(address user, uint256 earned_) public {
        earned[user] = earned_;
    }

    function setStakingToken(address stakingToken_) public {
        stakingToken = stakingToken_;
    }

    function setRewardToken(address rewardToken_) public {
        rewardToken = rewardToken_;
    }

    function deposit(uint256 amount) external {
        IERC20(stakingToken).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        IERC20(stakingToken).transfer(msg.sender, amount);
    }

    function getReward(address account) external {
        IERC20(rewardToken).transfer(account, earned[account]);
    }
}
