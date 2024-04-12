/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { StakingAMExtension } from "../../extensions/StakingAMExtension.sol";

contract StakingAMMock is StakingAMExtension {
    constructor(address registry, string memory name_, string memory symbol_, address rewardToken)
        StakingAMExtension(registry, name_, symbol_)
    {
        REWARD_TOKEN = ERC20(rewardToken);
    }

    mapping(address asset => uint256 rewardBalance) public currentRewardGlobal;

    function setActualRewardBalance(address asset, uint256 amount) public {
        currentRewardGlobal[asset] = amount;
    }

    function _stakeAndClaim(address asset, uint256) internal override {
        _claimReward(asset);
    }

    function _withdrawAndClaim(address asset, uint256) internal override {
        _claimReward(asset);
    }

    function _claimReward(address asset) internal override {
        currentRewardGlobal[asset] = 0;
    }

    function _getCurrentReward(address asset) internal view override returns (uint256 earned) {
        earned = currentRewardGlobal[asset];
    }
}
