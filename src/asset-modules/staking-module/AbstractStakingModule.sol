/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC1155 } from "../../../lib/solmate/src/tokens/ERC1155.sol";
import { ReentrancyGuard } from "../../../lib/solmate/src/utils/ReentrancyGuard.sol";
import { ERC20, SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

abstract contract AbstractStakingModule is ERC1155, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // A counter that will increment the id for each new staking token added.
    uint256 internal idCounter;

    // Map a staking token to it's token id.
    mapping(address stakingToken => uint256 id) public stakingTokenToId;
    // Map a token id to it's corresponding staking token.
    mapping(uint256 id => ERC20 stakingToken) public stakingToken;
    // Map a token id to it's corresponding reward token.
    mapping(uint256 id => ERC20 rewardToken) public rewardToken;
    // Map a token id to it's corresponding struct containing general info.
    mapping(uint256 id => IdToInfo) public idToInfo;
    // Map a token id and an Account to it's corresponding struct containing reward information for that account.
    mapping(uint256 id => mapping(address account => AccountRewardInfo)) public idToAccountRewardInfo;

    // Struct with the general information that should be kept relative to a token id.
    struct IdToInfo {
        uint128 rewardPerTokenStored;
        uint128 previousRewardBalance;
        uint128 totalSupply;
    }

    // Struct containing the information needed for rewards
    struct AccountRewardInfo {
        uint128 rewards;
        uint128 userRewardPerTokenPaid;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event Staked(address indexed account, uint256 id, uint128 amount);
    event Withdrawn(address indexed account, uint256 id, uint128 amount);
    event RewardPaid(address indexed account, uint256 id, uint256 reward);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AmountIsZero();
    error NoReentry();
    error InvalidTokenDecimals();

    /*///////////////////////////////////////////////////////////////
                        STAKINGTOKEN INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total supply of a specific token staked via this contract.
     * @param id The id of the specific staking token.
     * @return totalSupply_ The total supply of the staking token staked via this contract.
     */
    function totalSupply(uint256 id) external view returns (uint256 totalSupply_) {
        return idToInfo[id].totalSupply;
    }

    /**
     * @notice Adds a new staking token with it's corresponding reward token.
     * @param stakingToken_ The address of the staking token.
     * @param rewardToken_ The address of the reward token.
     */
    function addNewStakingToken(address stakingToken_, address rewardToken_) public {
        // Cache new id
        uint256 newId;
        unchecked {
            newId = ++idCounter;
        }

        // Cache tokens decimals
        uint256 stakingTokenDecimals_ = ERC20(stakingToken_).decimals();
        uint256 rewardTokenDecimals_ = ERC20(rewardToken_).decimals();

        if (stakingTokenDecimals_ > 18 || rewardTokenDecimals_ > 18) revert InvalidTokenDecimals();

        stakingToken[newId] = ERC20(stakingToken_);
        rewardToken[newId] = ERC20(rewardToken_);
        stakingTokenToId[stakingToken_] = newId;
    }

    /*///////////////////////////////////////////////////////////////
                           (UN)STAKING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function stake(uint256 id, uint128 amount) external nonReentrant {
        if (amount == 0) revert AmountIsZero();

        // Need to transfer the underlying asset before minting or ERC777s could reenter.
        stakingToken[id].safeTransferFrom(msg.sender, address(this), amount);

        // Calculate the updated reward balances.
        (uint256 currentRewardsBalance, uint256 currentRewardPerToken, uint256 currentReward, uint256 totalSupply_) =
            _getCurrentBalances(id, msg.sender);

        // Update the state variables.
        if (totalSupply_ > 0) {
            idToInfo[id].previousRewardBalance = uint128(currentRewardsBalance);
            idToInfo[id].rewardPerTokenStored = uint128(currentRewardPerToken);
            idToAccountRewardInfo[id][msg.sender] = AccountRewardInfo({
                rewards: uint128(currentReward),
                userRewardPerTokenPaid: uint128(currentRewardPerToken)
            });
        }
        idToInfo[id].totalSupply = uint128(totalSupply_ + amount);

        // Stake the underlying tokens into the external staking contract.
        _mint(msg.sender, id, amount, "");
        _stake(id, amount);

        emit Staked(msg.sender, id, amount);
    }

    /**
     * @notice Internal function to stake an amount of tokens in the external staking contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of tokens to stake.
     */
    function _stake(uint256 id, uint256 amount) internal virtual;

    function _getCurrentBalances(uint256 id, address account)
        internal
        view
        returns (
            uint256 currentRewardsBalance,
            uint256 currentRewardPerToken,
            uint256 currentReward,
            uint256 totalSupply_
        )
    {
        IdToInfo memory idToInfo_ = idToInfo[id];
        totalSupply_ = idToInfo_.totalSupply;
        if (totalSupply_ > 0) {
            // Fetch the current reward balance from the staking contract.
            currentRewardsBalance = _getActualRewardsBalance(id);

            // Calculate the increase in rewards since last contract interaction.
            uint256 deltaRewards = currentRewardsBalance - idToInfo_.previousRewardBalance;

            // Calculate the new RewardPerToken.
            currentRewardPerToken =
                idToInfo_.rewardPerTokenStored + deltaRewards.mulDivDown(1e18, idToInfo_.totalSupply);

            // Calculate rewards of the account.
            uint256 accountBalance = balanceOf[account][id];
            if (accountBalance > 0) {
                AccountRewardInfo memory accountRewardInfo = idToAccountRewardInfo[id][account];
                // Calculate the difference in rewardPerToken since the last interaction of the account with this contract.
                uint256 deltaRewardPerToken = currentRewardPerToken - accountRewardInfo.userRewardPerTokenPaid;
                // Calculate the pending rewards earned by the Account since its last interaction with this contract.
                currentReward = accountRewardInfo.rewards + accountBalance.mulDivDown(deltaRewardPerToken, 1e18);
            }
        }
    }

    function withdraw(uint256 id, uint128 amount) external nonReentrant {
        if (amount == 0) revert AmountIsZero();

        // Calculate the updated reward balances.
        (, uint256 currentRewardPerToken, uint256 currentReward, uint256 totalSupply_) =
            _getCurrentBalances(id, msg.sender);

        // Update the state variables.
        if (totalSupply_ > 0) {
            idToInfo[id].rewardPerTokenStored = uint128(currentRewardPerToken);
            // Reset pending rewardBalance and pending Account rewards since rewards are claimed and paid out to Account in withdraw.
            idToInfo[id].previousRewardBalance = 0;
            idToAccountRewardInfo[id][msg.sender] =
                AccountRewardInfo({ rewards: 0, userRewardPerTokenPaid: uint128(currentRewardPerToken) });
        }
        idToInfo[id].totalSupply = uint128(totalSupply_ - amount);

        // Withdraw the underlying tokens from external staking contract.
        _burn(msg.sender, id, amount);
        _withdraw(id, amount);

        // Claim all staking rewards.
        _claimRewards(id);
        // Pay out the share of rewards owed to the Account.
        if (currentReward > 0) {
            rewardToken[id].safeTransfer(msg.sender, currentReward);
            emit RewardPaid(msg.sender, id, currentReward);
        }

        // Transfer the underlying tokens back to the Account.
        stakingToken[id].safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, id, amount);
    }

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of tokens to withdraw.
     */
    function _withdraw(uint256 id, uint256 amount) internal virtual;

    /*///////////////////////////////////////////////////////////////
                        REWARDS ACCOUNTING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Claims the rewards available for this contract.
     * @param id The id of the specific staking token.
     */
    function _claimRewards(uint256 id) internal virtual;

    /**
     * @notice Returns the updated reward per token stored if rewards have accrued for this contract.
     * @param id The id of the specific staking token.
     * @return rewardPerToken_ The updated reward per token stored.
     */
    function rewardPerToken(uint256 id) public view returns (uint256 rewardPerToken_) {
        IdToInfo memory idToInfo_ = idToInfo[id];

        if (idToInfo_.totalSupply == 0) {
            return idToInfo_.rewardPerTokenStored;
        }

        // Calculate total earned rewards for this contract since last update.
        uint128 actualRewardsBalance = _getActualRewardsBalance(id);
        uint256 earnedSinceLastUpdate = actualRewardsBalance - idToInfo_.previousRewardBalance;

        rewardPerToken_ = idToInfo_.rewardPerTokenStored + earnedSinceLastUpdate.mulDivDown(1e18, idToInfo_.totalSupply);
    }

    /**
     * @notice Returns the amount of rewards claimable by an Account.
     * @param id The id of the specific staking token.
     * @param account The Account to calculate current rewards for.
     * @return earned The current amount of rewards earned by the Account.
     */
    function earnedByAccount(uint256 id, address account) public view returns (uint256 earned) {
        AccountRewardInfo memory idToAccountRewardInfo_ = idToAccountRewardInfo[id][account];

        uint256 rewardPerTokenClaimable = rewardPerToken(id) - idToAccountRewardInfo_.userRewardPerTokenPaid;
        earned = idToAccountRewardInfo_.rewards + balanceOf[account][id].mulDivDown(rewardPerTokenClaimable, 1e18);
    }

    /**
     * @notice Returns the amount of rewards earned by this contract.
     * @param id The id of the specific staking token.
     * @return earned The current amount of rewards earned by the the contract.
     */
    function _getActualRewardsBalance(uint256 id) internal view virtual returns (uint128 earned);

    function getReward(uint256 id) public nonReentrant {
        // Calculate the updated reward balances.
        (, uint256 currentRewardPerToken, uint256 currentReward, uint256 totalSupply_) =
            _getCurrentBalances(id, msg.sender);

        // Update the state variables.
        if (totalSupply_ > 0) {
            idToInfo[id].rewardPerTokenStored = uint128(currentRewardPerToken);
            // Reset pending rewardBalance and pending Account rewards since rewards are claimed and paid out to Account in getReward.
            idToInfo[id].previousRewardBalance = 0;
            idToAccountRewardInfo[id][msg.sender] =
                AccountRewardInfo({ rewards: 0, userRewardPerTokenPaid: uint128(currentRewardPerToken) });
        }

        // Claim all staking rewards.
        _claimRewards(id);
        // Pay out the share of rewards owed to the Account.
        if (currentReward > 0) {
            rewardToken[id].safeTransfer(msg.sender, currentReward);
            emit RewardPaid(msg.sender, id, currentReward);
        }
    }

    function uri(uint256 id) public view virtual override returns (string memory);
}
