/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakingModuleExtension } from "../Extensions.sol";

contract StakingModuleMock is StakingModuleExtension {
    constructor(string memory name_, string memory symbol_) StakingModuleExtension(name_, symbol_) { }

    mapping(address asset => uint256 rewardBalance) public currentRewardGlobal;

    function setActualRewardBalance(address asset, uint256 amount) public {
        currentRewardGlobal[asset] = amount;
    }

    function _stake(address asset, uint256 amount) internal override { }

    function _withdraw(address asset, uint256 amount) internal override { }

    function _claimReward(address asset) internal override {
        currentRewardGlobal[asset] = 0;
    }

    function _getCurrentReward(address asset) internal view override returns (uint256 earned) {
        earned = currentRewardGlobal[asset];
    }

    function tokenURI(uint256 id) public view override returns (string memory) { }
}
