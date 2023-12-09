// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import { StakingModuleExtension } from "../Extensions.sol";

contract StakingModuleMock is StakingModuleExtension {
    mapping(uint256 id => uint128 rewardBalance) public currentRewardGlobal;

    function setActualRewardBalance(uint256 id, uint128 amount) public {
        currentRewardGlobal[id] = amount;
    }

    function _stake(uint256 id, uint256 amount) internal override { }

    function _withdraw(uint256 id, uint256 amount) internal override { }

    function _claimReward(uint256 id) internal override {
        currentRewardGlobal[id] = 0;
    }

    function _getCurrentReward(uint256 id) internal view override returns (uint256 earned) {
        earned = currentRewardGlobal[id];
    }

    function uri(uint256 id) public view virtual override returns (string memory) { }
}
