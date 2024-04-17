/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { WrappedAMExtension } from "../../extensions/WrappedAMExtension.sol";

contract WrappedAMMock is WrappedAMExtension {
    constructor(address registry, string memory name_, string memory symbol_)
        WrappedAMExtension(registry, name_, symbol_)
    { }

    mapping(address asset => mapping(address rewardToken => uint256 currentRewardGlobal_) rewardBalance) public
        currentRewardBalance;

    function setCurrentRewardBalance(address asset, address rewardToken, uint256 rewardBalance) public {
        currentRewardBalance[asset][rewardToken] = rewardBalance;
    }

    function _claimRewards(address asset, address[] memory rewards) internal override {
        for (uint256 i; i < rewards.length; ++i) {
            currentRewardBalance[asset][rewards[i]] = 0;
        }
    }

    function _getCurrentRewards(address asset, address[] memory rewards)
        internal
        view
        override
        returns (uint256[] memory currentRewards)
    {
        currentRewards = new uint256[](rewards.length);
        for (uint256 i; i < rewards.length; ++i) {
            currentRewards[i] = currentRewardBalance[asset][rewards[i]];
        }
    }
}
