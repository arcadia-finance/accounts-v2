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
 * @dev The staking Module is an ERC721 contract that does the accounting per Account and per Asset (staking token) for:
 *  - The balances of Assets staked through this contract.
 *  - The balances of reward tokens earned for staking the Assets.
 * Next to keeping the accounting of balances, this contract manages the interactions with the external staking contract:
 *  - Staking Assets.
 *  - Withdrawing the Assets from staked positions.
 *  - Claiming reward tokens.
 */
abstract contract StakingModule is ERC721, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The id of last minted position.
    uint256 internal lastPositionId;

    // Map Asset to its corresponding reward token.
    mapping(address asset => ERC20 rewardToken) public assetToRewardToken;
    // Map Asset id to its corresponding struct with global state.
    mapping(address asset => AssetState) public assetState;
    // Map a position id to its corresponding struct with the position state.
    mapping(uint256 position => PositionState) public positionState;

    // Struct with the global state per Asset.
    struct AssetState {
        // The growth of reward tokens per Asset staked, at the last interaction with this contract,
        // with 18 decimals precision.
        uint128 lastRewardPerTokenGlobal;
        // The unclaimed amount of reward tokens, at the last interaction with this contract.
        uint128 lastRewardGlobal;
        // The total amount of Assets staked.
        uint128 totalStaked;
    }

    // Struct with the Position specific state.
    struct PositionState {
        // The staked Asset.
        address asset;
        // Total amount of Asset staked for this position.
        uint128 amountStaked;
        // The growth of reward tokens per Asset staked, at the last interaction of the Account with this contract,
        // with 18 decimals precision.
        uint128 lastRewardPerTokenPosition;
        // The unclaimed amount of reward tokens of the Account, at the last interaction of the Account with this contract.
        uint128 lastRewardPosition;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event RewardPaid(address indexed account, address reward, uint128 amount);
    event Minted(address indexed account, uint256 positionId, address asset, uint128 amount);
    event LiquidityIncreased(address indexed account, uint256 positionId, address asset, uint128 amount);
    event Withdrawn(address indexed account, address asset, uint128 amount);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetNotAllowed();
    error ZeroAmount();
    error NotOwner();
    error RemainingBalanceTooLow();
    error AssetNotMatching();

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) { }

    /*///////////////////////////////////////////////////////////////
                         STAKING MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of Assets in the external staking contract and mints a new position.
     * @param asset The id of the specific staking token.
     * @param amount The amount of Assets to stake.
     * @return positionId_ The id of the minted position.
     */
    function mint(address asset, uint128 amount) external nonReentrant returns (uint256 positionId_) {
        if (amount == 0) revert ZeroAmount();
        if (address(assetToRewardToken[asset]) == address(0)) revert AssetNotAllowed();

        // Need to transfer the Asset before minting or ERC777s could reenter.
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Cache assetState.
        AssetState memory assetState_ = assetState[asset];
        // Cache totalStaked
        uint256 totalStaked_ = assetState_.totalStaked;

        // Increment positionId
        unchecked {
            positionId_ = ++lastPositionId;
        }

        // Update the state variables.
        uint256 currentRewardGlobal;
        uint256 currentRewardPerToken;
        uint256 lastRewardPerTokenPosition;
        AssetState memory updatedAssetState;
        if (totalStaked_ > 0) {
            // Fetch the current reward balance from the staking contract.
            currentRewardGlobal = _getCurrentReward(asset);
            // Calculate the increase in rewards since last contract interaction.
            uint256 deltaReward = currentRewardGlobal - assetState_.lastRewardGlobal;
            // Calculate the new RewardPerToken.
            currentRewardPerToken = assetState_.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, totalStaked_);
            updatedAssetState.lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
            // We don't claim any rewards when staking, but minting changes the totalStaked and balance of the Asset.
            // Therefore we must keep track of the earned global and Account rewards since last interaction or the accounting will be wrong.
            updatedAssetState.lastRewardGlobal = uint128(currentRewardGlobal);
            lastRewardPerTokenPosition = currentRewardPerToken;
        }
        positionState[positionId_] = PositionState({
            asset: asset,
            amountStaked: amount,
            lastRewardPerTokenPosition: uint128(lastRewardPerTokenPosition),
            lastRewardPosition: 0
        });

        updatedAssetState.totalStaked = uint128(totalStaked_ + amount);
        assetState[asset] = updatedAssetState;

        // Mint the new position.
        _safeMint(msg.sender, positionId_);

        // Stake Asset in external staking contract.
        _stake(asset, amount);

        emit Minted(msg.sender, positionId_, asset, amount);
    }

    /**
     * @notice Increases liquidity for an existing position.
     * @param positionId The id of the position to increase the liquidity for.
     * @param asset The id of the specific staking token.
     * @param amount The amount of Assets to stake.
     */
    function increaseLiquidity(uint256 positionId, address asset, uint128 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (address(assetToRewardToken[asset]) == address(0)) revert AssetNotAllowed();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        PositionState storage positionState_ = positionState[positionId];

        if (positionState_.asset != asset) revert AssetNotMatching();

        AssetState storage assetState_ = assetState[asset];

        // Need to transfer the Asset before minting or ERC777s could reenter.
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Cache totalStaked, will always be > 0 in this scenario.
        uint256 totalStaked_ = assetState_.totalStaked;

        // Update asset state
        // Fetch the current reward balance from the staking contract.
        uint256 currentRewardGlobal = _getCurrentReward(asset);
        // Calculate the increase in rewards since last contract interaction.
        uint256 deltaReward = currentRewardGlobal - assetState_.lastRewardGlobal;
        // Calculate the new RewardPerToken.
        uint256 currentRewardPerToken =
            assetState_.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, totalStaked_);

        assetState[asset] = AssetState({
            lastRewardPerTokenGlobal: uint128(currentRewardPerToken),
            lastRewardGlobal: uint128(currentRewardGlobal),
            totalStaked: uint128(totalStaked_ + amount)
        });

        // Update position state
        // Calculate the difference in rewardPerToken since the last interaction of the account with this contract.
        uint256 deltaRewardPerToken = currentRewardPerToken - positionState_.lastRewardPerTokenPosition;
        // Calculate the rewards earned by the Account since its last interaction with this contract.
        uint256 accruedRewards = uint256(positionState_.amountStaked).mulDivDown(deltaRewardPerToken, 1e18);

        positionState_.lastRewardPerTokenPosition = uint128(currentRewardPerToken);
        positionState_.amountStaked += amount;
        positionState_.lastRewardPosition += uint128(accruedRewards);

        // Stake Asset in external staking contract.
        _stake(asset, amount);

        emit LiquidityIncreased(msg.sender, positionId, asset, amount);
    }

    /**
     * @notice Unstakes and withdraws the Asset from the external staking contract.
     * @param positionId The id of the position to withdraw from.
     * @param amount The amount of Asset to unstake and withdraw.
     */
    function withdraw(uint256 positionId, uint128 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        PositionState memory positionState_ = positionState[positionId];

        // Cache variable
        address asset = positionState_.asset;
        if (positionState_.amountStaked < amount) revert RemainingBalanceTooLow();

        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken, uint256 totalStaked_, uint256 currentRewardPosition) =
            _getCurrentBalances(positionState_);

        // Update the state variables.
        // Reset the balances of the pending rewards for the Asset and the position
        // since rewards are claimed and paid out to Account on a withdraw.
        assetState[asset] = AssetState({
            lastRewardPerTokenGlobal: uint128(currentRewardPerToken),
            lastRewardGlobal: 0,
            totalStaked: uint128(totalStaked_ - amount)
        });

        positionState[positionId].lastRewardPerTokenPosition = uint128(currentRewardPerToken);
        positionState[positionId].lastRewardPosition = 0;
        positionState[positionId].amountStaked -= amount;

        // Withdraw the Assets from external staking contract.
        if (amount == positionState_.amountStaked) _burn(positionId);
        _withdraw(asset, amount);
        // Claim the reward from the external staking contract.
        _claimReward(asset);
        // Pay out the share of the reward owed to the Account.
        if (currentRewardPosition > 0) {
            // Cache reward token
            ERC20 rewardToken_ = assetToRewardToken[asset];
            // Transfer reward
            rewardToken_.safeTransfer(msg.sender, currentRewardPosition);
            emit RewardPaid(msg.sender, address(rewardToken_), uint128(currentRewardPosition));
        }
        // Transfer the Asset back to the Account.
        ERC20(asset).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, asset, amount);
    }

    /**
     * @notice Claims the pending reward tokens of the caller.
     * @param positionId The id of the position to claim the rewards for.
     */
    function claimReward(uint256 positionId) external virtual nonReentrant {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        PositionState memory positionState_ = positionState[positionId];

        // Calculate the updated reward balances.
        (uint256 currentRewardPerToken,, uint256 currentRewardClaimable) = _getCurrentBalances(positionState_);

        address asset = positionState[positionId].asset;
        // Update the state variables.
        // Reset the balances of the pending rewards for the Asset and position,
        // since rewards are claimed and paid out to Account on a claimReward.
        assetState[asset].lastRewardPerTokenGlobal = uint128(currentRewardPerToken);
        assetState[asset].lastRewardGlobal = 0;

        positionState[positionId].lastRewardPerTokenPosition = uint128(currentRewardPerToken);
        positionState[positionId].lastRewardPosition = 0;

        // Claim the reward from the external staking contract.
        _claimReward(asset);
        // Pay out the share of the reward owed to the Account.
        if (currentRewardClaimable > 0) {
            // Cache reward
            ERC20 rewardToken_ = assetToRewardToken[asset];
            // Transfer reward
            rewardToken_.safeTransfer(msg.sender, currentRewardClaimable);
            emit RewardPaid(msg.sender, address(rewardToken_), uint128(currentRewardClaimable));
        }
    }

    /**
     * @notice Returns the total amount of Asset staked via this contract.
     * @param asset The Asset staked via this contract.
     * @return totalStaked_ The total amount of Asset staked via this contract.
     */
    function totalStaked(address asset) external view returns (uint256 totalStaked_) {
        return assetState[asset].totalStaked;
    }

    /*///////////////////////////////////////////////////////////////
                    INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens in the external staking contract.
     * @param asset The Asset to stake.
     * @param amount The amount of Asset to stake.
     */
    function _stake(address asset, uint256 amount) internal virtual;

    /**
     * @notice Unstakes and withdraws the Asset from the external contract.
     * @param asset The Asset to withdraw.
     * @param amount The amount of Asset to unstake and withdraw.
     */
    function _withdraw(address asset, uint256 amount) internal virtual;

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The asset for which rewards will be claimed.
     */
    function _claimReward(address asset) internal virtual;

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract for a specific Asset.
     * @param asset The Asset that is earning rewards from staking.
     * @return currentReward The amount of rewards tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view virtual returns (uint256 currentReward);

    /*///////////////////////////////////////////////////////////////
                         REWARDS VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of reward tokens claimable by a position.
     * @param positionId The id of the position to check the rewards for.
     * @return currentRewardClaimable The current amount of reward tokens claimable by the owner of the position.
     */
    function rewardOf(uint256 positionId) public view returns (uint256 currentRewardClaimable) {
        (,, currentRewardClaimable) = _getCurrentBalances(positionState[positionId]);
    }

    /**
     * @notice Calculates the current global and position specific reward balances for a given position id.
     * @param positionState_ The position struct with current state of the position.
     * @return currentRewardPerToken The growth of reward tokens per Asset staked, with 18 decimals precision.
     * @return totalStaked_ The total amount of Asset staked.
     * @return currentRewardPosition The unclaimed amount of reward tokens for the position.
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

            // Calculate rewards of the position.
            // Calculate the difference in rewardPerToken since the last interaction of the position owner with this contract.
            uint256 deltaRewardPerToken = currentRewardPerToken - positionState_.lastRewardPerTokenPosition;
            // Calculate the pending rewards earned by the position since its last interaction with this contract.
            currentRewardPosition =
                positionState_.lastRewardPosition + positionAmountStaked.mulDivDown(deltaRewardPerToken, 1e18);
        }
    }
}
