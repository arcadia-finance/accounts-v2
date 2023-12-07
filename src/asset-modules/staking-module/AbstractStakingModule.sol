/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakingModuleErrors } from "../../libraries/Errors.sol";
import { ERC1155 } from "../../../lib/solmate/src/tokens/ERC1155.sol";
import { ERC20, SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

abstract contract AbstractStakingModule is ERC1155 {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // A counter that will increment the id for each new staking token added.
    uint256 internal idCounter;
    // Flag Indicating if a function is locked to protect against reentrancy.
    uint256 internal locked = 1;

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
        uint64 stakingTokenWeiUnit;
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
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Throws if function is reentered.
     */
    modifier nonReentrant() {
        if (locked != 1) revert StakingModuleErrors.NoReentry();
        locked = 2;
        _;
        locked = 1;
    }

    /*///////////////////////////////////////////////////////////////
                        STAKINGTOKEN INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total supply of a specific token staked via this contract.
     * @param id The id of the specific staking token.
     * @return _totalSupply The total supply of the staking token staked via this contract.
     */
    function totalSupply(uint256 id) external view returns (uint128 _totalSupply) {
        return idToInfo[id].totalSupply;
    }

    /**
     * @notice Adds a new staking token with it's corresponding reward token.
     * @param stakingToken_ The address of the staking token.
     * @param rewardToken_ The address of the reward token.
     */
    function addNewStakingToken(address stakingToken_, address rewardToken_) public {
        // Cache new id
        uint256 newId = ++idCounter;

        // Cache tokens decimals
        uint256 stakingTokenDecimals_ = ERC20(stakingToken_).decimals();
        uint256 rewardTokenDecimals_ = ERC20(rewardToken_).decimals();

        if (stakingTokenDecimals_ > 18 || rewardTokenDecimals_ > 18) revert StakingModuleErrors.InvalidTokenDecimals();
        if (stakingTokenDecimals_ < 6 || rewardTokenDecimals_ < 6) revert StakingModuleErrors.InvalidTokenDecimals();

        stakingToken[newId] = ERC20(stakingToken_);
        rewardToken[newId] = ERC20(rewardToken_);
        stakingTokenToId[stakingToken_] = newId;
        idToInfo[newId].stakingTokenWeiUnit = uint64(10 ** stakingTokenDecimals_);
    }

    /*///////////////////////////////////////////////////////////////
                           (UN)STAKING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens for the caller and mints the corresponding ERC1155 token.
     * @param id The id of the specific staking token.
     * @param amount The amount of tokens to stake.
     */
    function stake(uint256 id, uint128 amount) external nonReentrant {
        if (amount == 0) revert StakingModuleErrors.AmountIsZero();

        _updateReward(id, msg.sender, false);

        stakingToken[id].safeTransferFrom(msg.sender, address(this), amount);

        idToInfo[id].totalSupply += amount;
        _mint(msg.sender, id, amount, "");

        // Will stake stakingToken in external staking contract.
        _stake(id, amount);

        emit Staked(msg.sender, id, amount);
    }

    /**
     * @notice Internal function to stake an amount of tokens in the external staking contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of tokens to stake.
     */
    function _stake(uint256 id, uint256 amount) internal virtual { }

    /**
     * @notice Unstakes and withdraws the specific staking token from the external contract and claims all pending rewards.
     * @param id The id of the specific staking token.
     * @param amount The amount of tokens to withdraw.
     */
    function withdraw(uint256 id, uint128 amount) external nonReentrant {
        if (amount == 0) revert StakingModuleErrors.AmountIsZero();

        _updateReward(id, msg.sender, true);

        idToInfo[id].totalSupply -= amount;
        _burn(msg.sender, id, amount);

        // Withdraw staked tokens from external staking contract.
        _withdraw(id, amount);
        // Claim rewards
        _getReward(id);

        stakingToken[id].safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, id, amount);
    }

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of tokens to withdraw.
     */
    function _withdraw(uint256 id, uint256 amount) internal virtual { }

    /*///////////////////////////////////////////////////////////////
                        REWARDS ACCOUNTING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Will update the rewards claimable on this contract.
     * @param id The id of the specific staking token.
     * @param account The Account for which updating the rewards.
     * @param claimRewards Is set to "true" if the action necessits to claim available rewards for this contract.
     */
    function _updateReward(uint256 id, address account, bool claimRewards) internal {
        // Note : We might increment rewardPerTokenStored directly in _rewardPerToken()
        idToInfo[id].rewardPerTokenStored = _rewardPerToken(id, claimRewards);

        // Rewards should be claimed before calling earnedByAccount, otherwise accounting is not correct.
        if (claimRewards) _claimRewards(id);

        AccountRewardInfo storage accountRewardInfo = idToAccountRewardInfo[id][account];
        // TODO : we can optimizez earnedByAccount to not call second time rewardPerToken()
        accountRewardInfo.rewards = earnedByAccount(id, account);
        accountRewardInfo.userRewardPerTokenPaid = idToInfo[id].rewardPerTokenStored;
    }

    /**
     * @notice Claims the rewards available for this contract.
     * @param id The id of the specific staking token.
     */
    function _claimRewards(uint256 id) internal virtual { }

    /**
     * @notice Returns the updated reward per token stored if rewards have accrued for this contract.
     * @param id The id of the specific staking token.
     * @param claimRewards Is set to "true" if the action necessits to claim the available rewards from external contract.
     * @return rewardPerToken_ The updated reward per token stored.
     */
    function _rewardPerToken(uint256 id, bool claimRewards) internal returns (uint128 rewardPerToken_) {
        IdToInfo storage idToInfo_ = idToInfo[id];

        // Cache totalSupply
        uint256 totalSupply_ = idToInfo_.totalSupply;

        if (totalSupply_ == 0) return idToInfo_.rewardPerTokenStored;

        // Calculate total earned rewards for this contract since last update.
        uint128 actualRewardsBalance = _getActualRewardsBalance(id);
        uint256 earnedSinceLastUpdate = actualRewardsBalance - idToInfo_.previousRewardBalance;

        idToInfo[id].previousRewardBalance = claimRewards ? 0 : actualRewardsBalance;

        rewardPerToken_ = idToInfo_.rewardPerTokenStored
            + uint128(earnedSinceLastUpdate.mulDivDown(idToInfo_.stakingTokenWeiUnit, totalSupply_));
    }

    /**
     * @notice Returns the updated reward per token stored if rewards have accrued for this contract.
     * @param id The id of the specific staking token.
     * @return rewardPerToken_ The updated reward per token stored.
     */
    function rewardPerToken(uint256 id) public view returns (uint128 rewardPerToken_) {
        IdToInfo storage idToInfo_ = idToInfo[id];

        // Cache totalSupply
        uint256 totalSupply_ = idToInfo_.totalSupply;

        if (totalSupply_ == 0) {
            return idToInfo_.rewardPerTokenStored;
        }

        // Calculate total earned rewards for this contract since last update.
        uint128 actualRewardsBalance = _getActualRewardsBalance(id);
        uint256 earnedSinceLastUpdate = actualRewardsBalance - idToInfo_.previousRewardBalance;

        rewardPerToken_ = idToInfo_.rewardPerTokenStored
            + uint128(earnedSinceLastUpdate.mulDivDown(idToInfo_.stakingTokenWeiUnit, totalSupply_));
    }

    /**
     * @notice Returns the amount of rewards claimable by an Account.
     * @param id The id of the specific staking token.
     * @param account The Account to calculate current rewards for.
     * @return earned The current amount of rewards earned by the Account.
     */
    function earnedByAccount(uint256 id, address account) public view returns (uint128 earned) {
        // Note: see if we can optimize rewardPerToken here, as we calculate it in modifier previously.
        AccountRewardInfo storage idToAccountRewardInfo_ = idToAccountRewardInfo[id][account];

        uint256 rewardPerTokenClaimable = rewardPerToken(id) - idToAccountRewardInfo_.userRewardPerTokenPaid;
        earned = idToAccountRewardInfo_.rewards
            + uint128(balanceOf[account][id].mulDivDown(rewardPerTokenClaimable, idToInfo[id].stakingTokenWeiUnit));
    }

    /**
     * @notice Returns the amount of rewards earned by this contract.
     * @param id The id of the specific staking token.
     * @return earned The current amount of rewards earned by the the contract.
     */
    function _getActualRewardsBalance(uint256 id) internal view virtual returns (uint128 earned) { }

    /**
     * @notice Claims the rewards available for an Account.
     * @param id The id of the specific staking token.
     */
    function getReward(uint256 id) public nonReentrant {
        _updateReward(id, msg.sender, true);
        _getReward(id);
    }

    /**
     * @notice Claims the rewards available for an Account.
     * @param id The id of the specific staking token.
     */
    function _getReward(uint256 id) internal {
        uint256 reward = idToAccountRewardInfo[id][msg.sender].rewards;

        if (reward > 0) {
            idToAccountRewardInfo[id][msg.sender].rewards = 0;
            rewardToken[id].safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, id, reward);
        }
    }

    function uri(uint256 id) public view virtual override returns (string memory) { }
}
