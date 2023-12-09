/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC1155 } from "../../../lib/solmate/src/tokens/ERC1155.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { ReentrancyGuard } from "../../../lib/solmate/src/utils/ReentrancyGuard.sol";
import { SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Staking Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a wrapper contract for Assets staked in an external staking contract.
 * @dev The staking Module is an ERC1155 contract that does the accounting per Account and per staking Token for:
 *  - The balances of underlying tokens staked through this contract.
 *  - The balances of reward tokens earned for staking the underlying tokens.
 * Next to keeping the accounting of balances, this contract manages the interactions with the external staking contract:
 *  - Staking underlying tokens.
 *  - Withdrawing the underlying tokens from staked positions.
 *  - Claiming reward tokens.
 */
abstract contract StakingModule is ERC1155, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The id of the latest added staking token.
    uint256 internal lastId;

    // Map underlying token and reward token pair to their corresponding staking token id.
    mapping(address underlyingToken => mapping(address rewardToken => uint256 id)) public tokenToRewardToId;
    // Map staking token id to it's corresponding underlying token.
    mapping(uint256 id => ERC20 underlyingToken) public underlyingToken;
    // Map staking token id to it's corresponding reward token.
    mapping(uint256 id => ERC20 rewardToken) public rewardToken;
    // Map staking token id to it's corresponding struct with global state.
    mapping(uint256 id => TokenState) public tokenState;
    // Map Account and staking token id to it's corresponding struct with the account specific state.
    mapping(address account => mapping(uint256 id => AccountState)) public accountState;

    // Struct with the global state per staking token.
    struct TokenState {
        // The growth of reward tokens per underlying token staked, at the last interaction with this contract,
        // with 18 decimals precision.
        uint128 lastRewardPerTokenGlobal;
        // The unclaimed amount of reward tokens, at the last interaction with this contract.
        uint128 lastRewardGlobal;
        // The total amount of underlying tokens staked.
        uint128 totalSupply;
    }

    // Struct with the Account specific state per staking token.
    struct AccountState {
        // The growth of reward tokens per underlying token staked, at the last interaction of the Account with this contract,
        // with 18 decimals precision.
        uint128 lastRewardPerTokenAccount;
        // The unclaimed amount of reward tokens of the Account, at the last interaction of the Account with this contract.
        uint128 lastRewardAccount;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event RewardPaid(address indexed account, uint256 id, uint256 reward);
    event Staked(address indexed account, uint256 id, uint128 amount);
    event Withdrawn(address indexed account, uint256 id, uint128 amount);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error InvalidTokenDecimals();
    error TokenToRewardPairAlreadySet();
    error ZeroAmount();

    /*///////////////////////////////////////////////////////////////
                        STAKING TOKEN MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new staking token with it's corresponding underlying and reward token.
     * @param underlyingToken_ The contract address of the underlying token.
     * @param rewardToken_ The contract address of the reward token.
     */
    function addNewStakingToken(address underlyingToken_, address rewardToken_) public {
        if (tokenToRewardToId[underlyingToken_][rewardToken_] != 0) revert TokenToRewardPairAlreadySet();

        // Cache new id
        uint256 newId;
        unchecked {
            newId = ++lastId;
        }

        // Cache tokens decimals
        uint256 underlyingTokenDecimals_ = ERC20(underlyingToken_).decimals();
        uint256 rewardTokenDecimals_ = ERC20(rewardToken_).decimals();

        if (underlyingTokenDecimals_ > 18 || rewardTokenDecimals_ > 18) revert InvalidTokenDecimals();

        underlyingToken[newId] = ERC20(underlyingToken_);
        rewardToken[newId] = ERC20(rewardToken_);
        tokenToRewardToId[underlyingToken_][rewardToken_] = newId;
    }

    /*///////////////////////////////////////////////////////////////
                    STAKING MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of underlying tokens in the external staking contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to stake.
     */
    function stake(uint256 id, uint128 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // Need to transfer the underlying asset before minting or ERC777s could reenter.
        underlyingToken[id].safeTransferFrom(msg.sender, address(this), amount);

        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken, uint256 currentRewardGlobal, uint256 totalSupply_, uint256 currentRewardSender)
        = _getCurrentBalances(msg.sender, id);

        // Update the state variables.
        if (totalSupply_ > 0) {
            tokenState[id].lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
            // We don't claim any rewards when staking, but minting changes the totalSupply and balance of the account.
            // Therefore we must keep track of the earned global and Account rewards since last interaction or the accounting will be wrong.
            tokenState[id].lastRewardGlobal = uint128(currentRewardGlobal);
            accountState[msg.sender][id] = AccountState({
                lastRewardPerTokenAccount: uint128(currentRewardPerToken),
                lastRewardAccount: uint128(currentRewardSender)
            });
        }
        tokenState[id].totalSupply = uint128(totalSupply_ + amount);

        // Stake the underlying tokens into the external staking contract.
        _mint(msg.sender, id, amount, "");
        _stake(id, amount);

        emit Staked(msg.sender, id, amount);
    }

    /**
     * @notice Unstakes and withdraws the underlying token from the external staking contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function withdraw(uint256 id, uint128 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken,, uint256 totalSupply_, uint256 currentRewardSender) =
            _getCurrentBalances(msg.sender, id);

        // Update the state variables.
        if (totalSupply_ > 0) {
            tokenState[id].lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
            // Reset the balances of the pending rewards for the token and Account,
            // since rewards are claimed and paid out to Account on a withdraw.
            tokenState[id].lastRewardGlobal = 0;
            accountState[msg.sender][id] =
                AccountState({ lastRewardPerTokenAccount: uint128(currentRewardPerToken), lastRewardAccount: 0 });
        }
        tokenState[id].totalSupply = uint128(totalSupply_ - amount);

        // Withdraw the underlying tokens from external staking contract.
        _burn(msg.sender, id, amount);
        _withdraw(id, amount);

        // Claim the reward from the external staking contract.
        _claimReward(id);
        // Pay out the share of the reward owed to the Account.
        if (currentRewardSender > 0) {
            rewardToken[id].safeTransfer(msg.sender, currentRewardSender);
            emit RewardPaid(msg.sender, id, currentRewardSender);
        }

        // Transfer the underlying tokens back to the Account.
        underlyingToken[id].safeTransfer(msg.sender, amount);

        emit Withdrawn(msg.sender, id, amount);
    }

    /**
     * @notice Claims the pending reward tokens of the caller.
     * @param id The id of the specific staking token.
     */
    function claimReward(uint256 id) public nonReentrant {
        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken,, uint256 totalSupply_, uint256 currentRewardSender) =
            _getCurrentBalances(msg.sender, id);

        // Update the state variables.
        if (totalSupply_ > 0) {
            tokenState[id].lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
            // Reset the balances of the pending rewards for the token and Account,
            // since rewards are claimed and paid out to Account on a claimReward.
            tokenState[id].lastRewardGlobal = 0;
            accountState[msg.sender][id] =
                AccountState({ lastRewardPerTokenAccount: uint128(currentRewardPerToken), lastRewardAccount: 0 });
        }

        // Claim the reward from the external staking contract.
        _claimReward(id);
        // Pay out the share of the reward owed to the Account.
        if (currentRewardSender > 0) {
            rewardToken[id].safeTransfer(msg.sender, currentRewardSender);
            emit RewardPaid(msg.sender, id, currentRewardSender);
        }
    }

    /*///////////////////////////////////////////////////////////////
                    INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens in the external staking contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to stake.
     */
    function _stake(uint256 id, uint256 amount) internal virtual;

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(uint256 id, uint256 amount) internal virtual;

    /**
     * @notice Claims the rewards available for this contract.
     * @param id The id of the specific staking token.
     */
    function _claimReward(uint256 id) internal virtual;

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract.
     * @param id The id of the specific staking token.
     * @return currentReward The amount of rewards tokens that can be claimed.
     */
    function _getCurrentReward(uint256 id) internal view virtual returns (uint256 currentReward);

    /*///////////////////////////////////////////////////////////////
                        REWARDS ACCOUNTING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total amount underlying token staked via this contract.
     * @param id The id of the staking token.
     * @return totalSupply_ The total amount underlying token staked.
     */
    function totalSupply(uint256 id) external view returns (uint256 totalSupply_) {
        return tokenState[id].totalSupply;
    }

    /**
     * @notice Returns the amount of reward tokens claimable by an Account.
     * @param account The address of the Account.
     * @param id The id of the specific staking token.
     * @return currentRewardAccount The current amount of reward tokens claimable by the Account.
     */
    function rewardOf(address account, uint256 id) public view returns (uint256 currentRewardAccount) {
        (,,, currentRewardAccount) = _getCurrentBalances(account, id);
    }

    /**
     * @notice Calculates the current global and Account specific reward balances for a given staking token and Account.
     * @param account The address of the Account.
     * @param id The id of the specific staking token.
     * @return currentRewardPerToken The growth of reward tokens per underlying token staked, with 18 decimals precision.
     * @return currentRewardGlobal The unclaimed amount of reward tokens for this contract.
     * @return totalSupply_ The total amount of underlying tokens staked.
     * @return currentRewardAccount The unclaimed amount of reward tokens for the Account..
     */
    function _getCurrentBalances(address account, uint256 id)
        internal
        view
        returns (
            uint256 currentRewardPerToken,
            uint256 currentRewardGlobal,
            uint256 totalSupply_,
            uint256 currentRewardAccount
        )
    {
        TokenState memory tokenState_ = tokenState[id];
        totalSupply_ = tokenState_.totalSupply;
        if (totalSupply_ > 0) {
            // Fetch the current reward balance from the staking contract.
            currentRewardGlobal = _getCurrentReward(id);

            // Calculate the increase in rewards since last contract interaction.
            uint256 deltaReward = currentRewardGlobal - tokenState_.lastRewardGlobal;

            // Calculate the new RewardPerToken.
            currentRewardPerToken =
                tokenState_.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, tokenState_.totalSupply);

            // Calculate rewards of the account.
            uint256 accountBalance = balanceOf[account][id];
            if (accountBalance > 0) {
                AccountState memory accountState_ = accountState[account][id];
                // Calculate the difference in rewardPerToken since the last interaction of the account with this contract.
                uint256 deltaRewardPerToken = currentRewardPerToken - accountState_.lastRewardPerTokenAccount;
                // Calculate the pending rewards earned by the Account since its last interaction with this contract.
                currentRewardAccount =
                    accountState_.lastRewardAccount + accountBalance.mulDivDown(deltaRewardPerToken, 1e18);
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                           ERC1155 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that returns the URI as defined in the ERC1155 standard.
     * @param id The id of the specific staking token.
     * @return uri The token URI.
     */
    function uri(uint256 id) public view virtual override returns (string memory);
}
