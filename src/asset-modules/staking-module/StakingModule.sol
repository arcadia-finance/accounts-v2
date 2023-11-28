/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC1155 } from "../../../lib/solmate/src/tokens/ERC1155.sol";
import { ERC20, SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

abstract contract StakingModule is ERC1155 {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    mapping(uint256 id => ERC20 stakingToken) public stakingToken;
    mapping(uint256 id => ERC20 rewardsToken) public rewardsToken;

    // Note: see if struct could be more efficient here. (How are mappings packed inside a struct/storage) ?
    mapping(uint256 id => uint256 rewardPerTokenStored) public rewardPerTokenStored;
    mapping(uint256 id => uint256 previousRewardsBalance) public previousRewardsBalance;
    mapping(uint256 id => uint256 totalSupply) public totalSupply_;

    mapping(uint256 id => mapping(address account => uint256 rewards)) public rewards;
    mapping(uint256 id => mapping(address account => uint256 rewardPerTokenPaid)) public userRewardPerTokenPaid;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event Staked(address indexed account, uint256 amount);
    event Withdrawn(address indexed account, uint256 amount);
    event RewardPaid(address indexed account, uint256 reward);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AmountIsZero();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    modifier updateReward(uint256 id, address account) {
        rewardPerTokenStored[id] = rewardPerToken(id);

        if (account != address(0)) {
            rewards[id][account] = earnedByAccount(id, account);
            userRewardPerTokenPaid[id][account] = rewardPerTokenStored[i];
        }

        _;
    }

    /*///////////////////////////////////////////////////////////////
                        STAKINGTOKEN INFORMATION
    ///////////////////////////////////////////////////////////////*/

    function totalSupply(uint256 id) external view returns (uint256) {
        return totalSupply_[id];
    }

    /*///////////////////////////////////////////////////////////////
                        STAKING LOGIC
    ///////////////////////////////////////////////////////////////*/

    // Note: add nonReentrant and notPaused modifiers ?
    // Note: See who can call this function
    // Stakes the stakingToken and handles accounting for Account.
    function stake(uint256 id, uint256 amount, address account) external updateReward(id, account) {
        if (amount == 0) revert AmountIsZero();

        stakingToken[id].safeTransferFrom(msg.sender, address(this), amount);

        totalSupply_[id] += amount;
        _mint(account, id, amount, "");

        // Internal function to stake in protocol
        _stake(amount);

        emit Staked(msg.sender, amount);
    }

    // Stake "stakingToken" in external staking contract.
    function _stake(uint256 id, uint256 amount) internal virtual { }

    // Note: add nonReentrant modifier?
    // Note: see who can call this function
    // Unstakes and withdraws the rewards.
    function withdraw(uint256 id, uint256 amount, address account) external updateReward(id, account) {
        if (amount == 0) revert AmountIsZero();

        totalSupply_[id] -= amount;
        _burn(account, id, amount);

        // Internal function to claim from protocol
        _withdraw(amount);

        emit Withdrawn(msg.sender, amount);
    }

    // Withdraw "stakingToken" from external staking contract.
    function _withdraw(uint256 id, uint256 amount) internal virtual { }

    /*///////////////////////////////////////////////////////////////
                        REWARDS ACCOUNTING LOGIC
    ///////////////////////////////////////////////////////////////*/

    // Updates the reward per token.
    function rewardPerToken(uint256 id) public view returns (uint256 rewardPerToken_) {
        if (totalSupply_[id] == 0) {
            return rewardPerTokenStored[id];
        }

        // Calc total earned amount of this contract as of now minus last time = earned over period.
        uint256 actualRewardsBalance = _getActualRewardsBalance(id);
        uint256 earnedSinceLastUpdate = actualRewardsBalance - previousRewardsBalance[id];

        rewardPerToken_ = rewardPerTokenStored[id] + earnedSinceLastUpdate.mulDivDown(1e18, totalSupply_[id]);
    }

    // Note: see if we can optimize rewardPerToken here, as we calculate it in modifier previously.
    function earnedByAccount(uint256 id, address account) public view returns (uint256 earned_) {
        uint256 rewardPerTokenClaimable = rewardPerToken() - userRewardPerTokenPaid[account];
        earned_ = rewards[id][account] + balanceOf[account][id].mulDivDown(rewardPerTokenClaimable, 1e18);
    }

    // Get the total rewards available to claim for this contract.
    function _getActualRewardsBalance(uint256 id) internal view virtual returns (uint256 earned) { }

    // Claim reward and transfer to Account
    function getReward(uint256 id, address account) external virtual updateReward(id, account) {
        uint256 reward = rewards[id][account];
        if (reward > 0) {
            rewards[id][account] = 0;
            rewardsToken[id].safeTransfer(msg.sender, reward);
            emit RewardPaid(account, reward);
        }
    }
}
