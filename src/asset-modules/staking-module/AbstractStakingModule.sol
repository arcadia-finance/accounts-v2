/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC1155 } from "../../../lib/solmate/src/tokens/ERC1155.sol";
import { ERC20, SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

abstract contract AbstractStakingModule is ERC1155 {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    uint256 internal idCounter;

    mapping(address stakingToken => uint256 id) public stakingTokenToId;
    mapping(uint256 id => ERC20 stakingToken) public stakingToken;
    mapping(uint256 id => ERC20 rewardToken) public rewardToken;
    mapping(uint256 id => uint256 decimals) public stakingTokenDecimals;

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
    error InvalidTokenDecimals();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    modifier updateReward(uint256 id, address account, bool claimRewards) {
        // Note : We might increment rewardPerTokenStored directly in _rewardPerToken()
        rewardPerTokenStored[id] = _rewardPerToken(id, claimRewards);

        // Rewards should be claimed before calling earnedByAccount, otherwise accounting is not correct.
        if (claimRewards) _claimRewards(id);

        if (account != address(0)) {
            // TODO : we can optimizez earnedByAccount to not call second time rewardPerToken()
            rewards[id][account] = earnedByAccount(id, account);
            userRewardPerTokenPaid[id][account] = rewardPerTokenStored[id];
        }

        _;
    }

    /*///////////////////////////////////////////////////////////////
                        STAKINGTOKEN INFORMATION
    ///////////////////////////////////////////////////////////////*/

    function totalSupply(uint256 id) external view returns (uint256) {
        return totalSupply_[id];
    }

    // Note: Should we make this one virtual ?
    // TODO : Add testing for errors
    function addNewStakingToken(address stakingToken_, address rewardToken_) public {
        // Cache new id
        uint256 newId = ++idCounter;

        // Cache tokens decimals
        uint256 stakingTokenDecimals_ = ERC20(stakingToken_).decimals();
        uint256 rewardTokenDecimals_ = ERC20(rewardToken_).decimals();

        if (stakingTokenDecimals_ > 18 || rewardTokenDecimals_ > 18) revert InvalidTokenDecimals();
        if (stakingTokenDecimals_ < 6 || rewardTokenDecimals_ < 6) revert InvalidTokenDecimals();

        stakingToken[newId] = ERC20(stakingToken_);
        rewardToken[newId] = ERC20(rewardToken_);
        stakingTokenToId[stakingToken_] = newId;
        stakingTokenDecimals[newId] = stakingTokenDecimals_;
    }

    /*///////////////////////////////////////////////////////////////
                        STAKING LOGIC
    ///////////////////////////////////////////////////////////////*/

    // Note: add nonReentrant and notPaused modifiers ?
    // Note: See who can call this function
    // Will revert in safeTransferFrom if "id" is not correct.
    // Stakes the stakingToken and handles accounting for Account.
    function stake(uint256 id, uint256 amount) external updateReward(id, msg.sender, false) {
        if (amount == 0) revert AmountIsZero();

        stakingToken[id].safeTransferFrom(msg.sender, address(this), amount);

        totalSupply_[id] += amount;
        _mint(msg.sender, id, amount, "");

        // Internal function to stake in external staking contract.
        _stake(id, amount);

        emit Staked(msg.sender, amount);
    }

    // Stake "stakingToken" in external staking contract.
    function _stake(uint256 id, uint256 amount) internal virtual { }

    // Note: add nonReentrant modifier?
    // Note: see who can call this function
    // Unstakes and withdraws the rewards.
    function withdraw(uint256 id, uint256 amount) external updateReward(id, msg.sender, true) {
        if (amount == 0) revert AmountIsZero();

        totalSupply_[id] -= amount;
        _burn(msg.sender, id, amount);

        // withdraw staked tokens
        _withdraw(id, amount);
        // claim rewards
        _getReward(id);

        stakingToken[id].safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    // Withdraw "stakingToken" from external staking contract and claim all rewards.
    function _withdraw(uint256 id, uint256 amount) internal virtual { }

    // Will claim all pending rewards for this contract
    function _claimRewards(uint256 id) internal virtual { }

    /*///////////////////////////////////////////////////////////////
                        REWARDS ACCOUNTING LOGIC
    ///////////////////////////////////////////////////////////////*/

    // Updates the reward per token.
    function _rewardPerToken(uint256 id, bool claimRewards) internal returns (uint256 rewardPerToken_) {
        if (totalSupply_[id] == 0) {
            return rewardPerTokenStored[id];
        }

        // Calc total earned amount of this contract as of now minus last time = earned over period.
        uint256 actualRewardsBalance = _getActualRewardsBalance(id);
        uint256 earnedSinceLastUpdate = actualRewardsBalance - previousRewardsBalance[id];

        previousRewardsBalance[id] = claimRewards ? 0 : actualRewardsBalance;

        rewardPerToken_ = rewardPerTokenStored[id]
            + earnedSinceLastUpdate.mulDivDown(10 ** stakingTokenDecimals[id], totalSupply_[id]);
    }

    function rewardPerToken(uint256 id) public view returns (uint256 rewardPerToken_) {
        if (totalSupply_[id] == 0) {
            return rewardPerTokenStored[id];
        }

        // Calc total earned amount of this contract as of now minus last time = earned over period.
        uint256 actualRewardsBalance = _getActualRewardsBalance(id);
        uint256 earnedSinceLastUpdate = actualRewardsBalance - previousRewardsBalance[id];

        rewardPerToken_ = rewardPerTokenStored[id]
            + earnedSinceLastUpdate.mulDivDown(10 ** stakingTokenDecimals[id], totalSupply_[id]);
    }

    // Note: see if we can optimize rewardPerToken here, as we calculate it in modifier previously.
    function earnedByAccount(uint256 id, address account) public view returns (uint256 earned_) {
        uint256 rewardPerTokenClaimable = rewardPerToken(id) - userRewardPerTokenPaid[id][account];
        earned_ = rewards[id][account]
            + balanceOf[account][id].mulDivDown(rewardPerTokenClaimable, 10 ** stakingTokenDecimals[id]);
    }

    // Get the total rewards available to claim for this contract.
    function _getActualRewardsBalance(uint256 id) internal view virtual returns (uint256 earned) { }

    // Claim reward and transfer to Account
    // Note: should that function be virtual ?
    function getReward(uint256 id) public updateReward(id, msg.sender, true) {
        uint256 reward = rewards[id][msg.sender];

        if (reward > 0) {
            rewards[id][msg.sender] = 0;
            rewardToken[id].safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function _getReward(uint256 id) internal {
        uint256 reward = rewards[id][msg.sender];

        _claimRewards(id);
        previousRewardsBalance[id] = 0;

        if (reward > 0) {
            rewards[id][msg.sender] = 0;
            rewardToken[id].safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function uri(uint256 id) public view override returns (string memory) { }
}
