/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../lib/solmate/src/tokens/ERC721.sol";
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
abstract contract StakingModule is ERC721, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The tokenId of last minted ERC721 token.
    uint256 internal lastId;

    // Map staking token id to its corresponding reward token.
    mapping(address asset => ERC20 rewardToken) public rewardToken;
    // Map staking token id to its corresponding struct with global state.
    mapping(address asset => AssetState) public assetState;
    // Map Account and staking token id to its corresponding struct with the account specific state.
    mapping(uint256 tokenId => PositionState) public positionState;

    // Struct with the global state per staking token.
    struct AssetState {
        // The growth of reward tokens per underlying token staked, at the last interaction with this contract,
        // with 18 decimals precision.
        uint128 lastRewardPerTokenGlobal;
        // The unclaimed amount of reward tokens, at the last interaction with this contract.
        uint128 lastRewardGlobal;
        // The total amount of underlying tokens staked.
        uint128 totalStaked;
    }

    // Struct with the Account specific state per staking token.
    struct PositionState {
        address owner;
        address asset;
        uint128 amountStaked;
        // The growth of reward tokens per underlying token staked, at the last interaction of the Account with this contract,
        // with 18 decimals precision.
        uint128 lastRewardPerTokenPosition;
        // The unclaimed amount of reward tokens of the Account, at the last interaction of the Account with this contract.
        uint128 lastRewardPosition;
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
    error AssetNotAllowed();
    error ZeroAmount();
    error NotOwner();
    error RemainingBalanceTooLow();
    error AssetNotMatching();

    /* //////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() ERC721("ArcadiaStargatePositions", "ASP") { }

    /*///////////////////////////////////////////////////////////////
                    STAKING MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of underlying tokens in the external staking contract.
     * @param asset The id of the specific staking token.
     * @param amount The amount of underlying tokens to stake.
     * @param receiver The address that will be the original owner of the ERC721 token.
     * @return tokenId_ ..
     */
    function stake(uint256 tokenId, address asset, uint128 amount, address receiver)
        external
        nonReentrant
        returns (uint256 tokenId_)
    {
        if (amount == 0) revert ZeroAmount();
        if (address(rewardToken[asset]) == address(0)) revert AssetNotAllowed();

        // Need to transfer the underlying asset before minting or ERC777s could reenter.
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Note : double check if receiver would be needed in existing position.
        if (tokenId == 0) {
            tokenId_ = _stakeNewPosition(asset, amount, receiver);
        } else {
            _stakeForExistingPosition(tokenId, asset, amount);
            tokenId_ = tokenId;
        }

        // Stake asset in external staking contract.
        _stake(asset, amount);

        // Note : check emit data
        emit Staked(msg.sender, 1, amount);
    }

    /**
     * @notice Unstakes and withdraws the underlying token from the external staking contract.
     * @param tokenId The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function withdraw(uint256 tokenId, uint128 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        PositionState memory positionState_ = positionState[tokenId];

        // Cache variable
        address asset = positionState_.asset;

        if (positionState_.amountStaked < amount) revert RemainingBalanceTooLow();

        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken, uint256 totalStaked_, uint256 currentRewardSender) =
            _getCurrentBalances(positionState_);

        // Update the state variables.
        if (totalStaked_ > 0) {
            assetState[asset].lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
            // Reset the balances of the pending rewards for the token and Account,
            // since rewards are claimed and paid out to Account on a withdraw.
            assetState[asset].lastRewardGlobal = 0;

            positionState[tokenId].lastRewardPerTokenPosition = uint128(currentRewardPerToken);
            positionState[tokenId].lastRewardPosition = 0;
        }
        positionState[tokenId].amountStaked -= amount;
        assetState[asset].totalStaked = uint128(totalStaked_ - amount);

        // Withdraw the underlying tokens from external staking contract.
        if (amount == positionState_.amountStaked) _burn(tokenId);
        _withdraw(asset, amount);

        // Claim the reward from the external staking contract.
        _claimReward(asset);
        // Pay out the share of the reward owed to the Account.
        if (currentRewardSender > 0) {
            rewardToken[asset].safeTransfer(msg.sender, currentRewardSender);
            // Note : check emit data
            emit RewardPaid(msg.sender, tokenId, currentRewardSender);
        }

        // Transfer the underlying tokens back to the Account.
        ERC20(asset).safeTransfer(msg.sender, amount);

        // Note : check emit data
        emit Withdrawn(msg.sender, tokenId, amount);
    }

    /**
     * @notice Claims the pending reward tokens of the caller.
     * @param tokenId The id of the specific staking token.
     */
    function claimReward(uint256 tokenId) external virtual nonReentrant {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        PositionState memory positionState_ = positionState[tokenId];

        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken, uint256 totalSupply_, uint256 currentRewardClaimable) =
            _getCurrentBalances(positionState_);

        address asset = positionState[tokenId].asset;
        // Update the state variables.
        if (totalSupply_ > 0) {
            assetState[asset].lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
            // Reset the balances of the pending rewards for the token and Account,
            // since rewards are claimed and paid out to Account on a claimReward.
            assetState[asset].lastRewardGlobal = 0;
            positionState[tokenId].lastRewardPerTokenPosition = uint128(currentRewardPerToken);
            positionState[tokenId].lastRewardPosition = 0;
        }

        // Claim the reward from the external staking contract.
        _claimReward(asset);
        // Pay out the share of the reward owed to the Account.
        if (currentRewardClaimable > 0) {
            rewardToken[asset].safeTransfer(msg.sender, currentRewardClaimable);
            // note : check emit data
            emit RewardPaid(msg.sender, tokenId, currentRewardClaimable);
        }
    }

    function _stakeForExistingPosition(uint256 tokenId, address asset, uint128 amount) internal {
        if (ownerOf(tokenId) != msg.sender) revert NotOwner();

        PositionState storage positionState_ = positionState[tokenId];
        AssetState storage assetState_ = assetState[asset];

        if (positionState_.asset != asset) revert AssetNotMatching();

        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken, uint256 currentRewardGlobal, uint256 totalStaked_) = _getCurrentBalances(asset);

        // Update the state variables.
        if (totalStaked_ > 0) {
            assetState_.lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
            // We don't claim any rewards when staking, but minting changes the totalSupply and balance of the account.
            // Therefore we must keep track of the earned global and Account rewards since last interaction or the accounting will be wrong.
            assetState_.lastRewardGlobal = uint128(currentRewardGlobal);
            positionState_.lastRewardPerTokenPosition = uint128(currentRewardPerToken);
        }

        positionState_.amountStaked += amount;

        assetState_.totalStaked = uint128(totalStaked_ + amount);
    }

    function _stakeNewPosition(address asset, uint128 amount, address receiver) internal returns (uint256 newId) {
        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken, uint256 currentRewardGlobal, uint256 totalStaked_) = _getCurrentBalances(asset);

        // Increment tokenId
        unchecked {
            newId = ++lastId;
        }

        PositionState storage positionState_ = positionState[newId];
        AssetState storage assetState_ = assetState[asset];

        // Update the state variables.
        if (totalStaked_ > 0) {
            assetState_.lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
            // We don't claim any rewards when staking, but minting changes the totalSupply and balance of the account.
            // Therefore we must keep track of the earned global and Account rewards since last interaction or the accounting will be wrong.
            assetState_.lastRewardGlobal = uint128(currentRewardGlobal);
            positionState_.lastRewardPerTokenPosition = uint128(currentRewardPerToken);
        }
        positionState_.owner = receiver;
        positionState_.asset = asset;
        positionState_.amountStaked = amount;

        assetState_.totalStaked = uint128(totalStaked_ + amount);

        // Mint the new position.
        _safeMint(msg.sender, newId);
    }

    /*///////////////////////////////////////////////////////////////
                    INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens in the external staking contract.
     * @param asset The id of the specific staking token.
     * @param amount The amount of underlying tokens to stake.
     */
    function _stake(address asset, uint256 amount) internal virtual;

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param asset The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(address asset, uint256 amount) internal virtual;

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The id of the specific staking token.
     */
    function _claimReward(address asset) internal virtual;

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract.
     * @param asset The id of the specific staking token.
     * @return currentReward The amount of rewards tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view virtual returns (uint256 currentReward);

    /*///////////////////////////////////////////////////////////////
                        REWARDS ACCOUNTING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the total amount underlying token staked via this contract.
     * @param asset The id of the staking token.
     * @return totalSupply_ The total amount underlying token staked.
     */
    function totalStaked(address asset) external view returns (uint256 totalSupply_) {
        return assetState[asset].totalStaked;
    }

    /**
     * @notice Returns the amount of reward tokens claimable by an Account.
     * @param tokenId The address of the Account.
     * @return currentRewardClaimable The current amount of reward tokens claimable by the Account.
     */
    function rewardOf(uint256 tokenId) public view returns (uint256 currentRewardClaimable) {
        (,, currentRewardClaimable) = _getCurrentBalances(positionState[tokenId]);
    }

    /**
     * @notice Calculates the current global and Account specific reward balances for a given tokenId.
     * @param positionState_ The address of the Account.
     * @return currentRewardPerToken The growth of reward tokens per underlying token staked, with 18 decimals precision.
     * @return totalStaked_ The total amount of underlying tokens staked.
     * @return currentRewardPosition The unclaimed amount of reward tokens for the Account..
     */
    function _getCurrentBalances(PositionState memory positionState_)
        internal
        view
        returns (uint256 currentRewardPerToken, uint256 totalStaked_, uint256 currentRewardPosition)
    {
        // Cache values
        address asset = positionState_.asset;
        uint256 positionAmountStaked = positionState_.amountStaked;

        AssetState memory assetState_ = assetState[asset];
        totalStaked_ = assetState_.totalStaked;

        if (totalStaked_ > 0) {
            // Fetch the current reward balance from the staking contract.
            uint256 currentRewardGlobal = _getCurrentReward(asset);

            // Calculate the increase in rewards since last contract interaction.
            uint256 deltaReward = currentRewardGlobal - assetState_.lastRewardGlobal;

            // Calculate the new RewardPerToken.
            currentRewardPerToken =
                assetState_.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, assetState_.totalStaked);

            // Calculate rewards of the account.
            if (positionAmountStaked > 0) {
                // Calculate the difference in rewardPerToken since the last interaction of the account with this contract.
                uint256 deltaRewardPerToken = currentRewardPerToken - positionState_.lastRewardPerTokenPosition;
                // Calculate the pending rewards earned by the Account since its last interaction with this contract.
                currentRewardPosition =
                    positionState_.lastRewardPosition + positionAmountStaked.mulDivDown(deltaRewardPerToken, 1e18);
            }
        }
    }

    function _getCurrentBalances(address asset)
        internal
        view
        returns (uint256 currentRewardPerToken, uint256 totalStaked_, uint256 currentRewardGlobal)
    {
        AssetState memory assetState_ = assetState[asset];
        totalStaked_ = assetState_.totalStaked;

        if (totalStaked_ > 0) {
            // Fetch the current reward balance from the staking contract.
            currentRewardGlobal = _getCurrentReward(asset);

            // Calculate the increase in rewards since last contract interaction.
            uint256 deltaReward = currentRewardGlobal - assetState_.lastRewardGlobal;

            // Calculate the new RewardPerToken.
            currentRewardPerToken =
                assetState_.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, assetState_.totalStaked);
        }
    }
}
