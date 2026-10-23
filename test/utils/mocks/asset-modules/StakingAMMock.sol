/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC20Mock } from "../tokens/ERC20Mock.sol";
import { StakingAMExtension } from "../../extensions/StakingAMExtension.sol";

contract StakingAMMock is StakingAMExtension {
    constructor(
        address owner_,
        address registry,
        string memory name_,
        string memory symbol_,
        address rewardToken,
        address surplusRecipient_
    ) StakingAMExtension(owner_, registry, name_, symbol_, surplusRecipient_) {
        REWARD_TOKEN = ERC20(rewardToken);
    }

    mapping(address asset => uint256 rewardBalance) public currentRewardGlobal;

    uint256 public bookedAmount;

    function setActualRewardBalance(address asset, uint256 amount) public {
        currentRewardGlobal[asset] = amount;
    }

    function setBookedAmount(uint256 amount) public {
        bookedAmount = amount;
    }

    function _stakeAndClaim(uint256 positionId, address asset, uint256) internal override returns (uint256 surplus) {
        surplus = _claimReward(positionId, asset);
    }

    function _withdrawAndClaim(uint256 positionId, address asset, uint256) internal override returns (uint256 surplus) {
        surplus = _claimReward(positionId, asset);
    }

    function _claimReward(uint256, address asset) internal override returns (uint256 surplus) {
        uint256 amount = currentRewardGlobal[asset];
        currentRewardGlobal[asset] = 0;

        if (amount > 0) ERC20Mock(address(REWARD_TOKEN)).mint(address(this), amount);

        surplus = bookedAmount;
        bookedAmount = 0;
    }

    function _getCurrentReward(uint256, address asset) internal view override returns (uint256 earned) {
        earned = currentRewardGlobal[asset];
    }
}
