// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { AbstractStakingModuleExtension } from "../Extensions.sol";

contract StakingModuleMock is AbstractStakingModuleExtension {
    mapping(uint256 id => uint128 rewardBalance) public actualRewardBalance;

    function setActualRewardBalance(uint256 id, uint128 amount) public {
        actualRewardBalance[id] = amount;
    }

    function _stake(uint256 id, uint256 amount) internal override { }

    function _withdraw(uint256 id, uint256 amount) internal override { }

    function _claimRewards(uint256 id) internal override {
        actualRewardBalance[id] = 0;
    }

    function _getActualRewardsBalance(uint256 id) internal view override returns (uint128 earned) {
        earned = actualRewardBalance[id];
    }
}
