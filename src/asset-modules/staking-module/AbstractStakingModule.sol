/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../lib/solmate/src/tokens/ERC721.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { ReentrancyGuard } from "../../../lib/solmate/src/utils/ReentrancyGuard.sol";

import { SafeCastLib } from "../../../lib/solmate/src/utils/SafeCastLib.sol";
import { SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title Staking Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a wrapper contract for Assets staked in an external staking contract.
 * @dev The staking Module is an ERC721 contract that does the accounting per Asset (staking token) and per position owner for:
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
    // Map Asset to its corresponding struct with global state.
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
        // The growth of reward tokens per Asset staked, at the last interaction of the position owner with this contract,
        // with 18 decimals precision.
        uint128 lastRewardPerTokenPosition;
        // The unclaimed amount of reward tokens of the position owner, at the last interaction of the owner with this contract.
        uint128 lastRewardPosition;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event LiquidityDecreased(address indexed owner, address asset, uint128 amount);
    event LiquidityIncreased(address indexed owner, uint256 positionId, address asset, uint128 amount);
    event Minted(address indexed owner, uint256 positionId, address asset, uint128 amount);
    event RewardPaid(address indexed owner, address reward, uint128 amount);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetNotAllowed();
    error NotOwner();
    error ZeroAmount();

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) { }

    /*///////////////////////////////////////////////////////////////
                         STAKING MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of Assets in the external staking contract and mints a new position.
     * @param asset The contract address of the Asset to stake.
     * @param amount The amount of Assets to stake.
     * @return positionId The id of the minted position.
     */
    function mint(address asset, uint128 amount) external nonReentrant returns (uint256 positionId) {
        if (amount == 0) revert ZeroAmount();
        if (address(assetToRewardToken[asset]) == address(0)) revert AssetNotAllowed();

        // Cache the old assetState and a positionState.
        AssetState memory assetState_ = assetState[asset];
        PositionState memory positionState_;
        positionState_.asset = asset;

        // Calculate the new reward balances.
        (assetState_, positionState_) = _getRewardBalances(assetState_, positionState_);

        // Calculate the new staked amounts.
        assetState_.totalStaked = assetState_.totalStaked + amount;
        positionState_.amountStaked = amount;

        // Store the new positionState and assetState.
        unchecked {
            positionId = ++lastPositionId;
        }
        positionState[positionId] = positionState_;
        assetState[asset] = assetState_;

        // Mint the new position.
        _safeMint(msg.sender, positionId);

        // Stake Asset in external staking contract.
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        _stake(asset, amount);

        emit Minted(msg.sender, positionId, asset, amount);
    }

    /**
     * @notice Stakes additional Assets in the external staking contract for an existing position.
     * @param positionId The id of the position.
     * @param amount The amount of Assets to stake.
     */
    function increaseLiquidity(uint256 positionId, uint128 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache the old positionState and assetState.
        PositionState memory positionState_ = positionState[positionId];
        AssetState memory assetState_ = assetState[positionState_.asset];

        // Calculate the new reward balances.
        (assetState_, positionState_) = _getRewardBalances(assetState_, positionState_);

        // Calculate the new staked amounts.
        assetState_.totalStaked = assetState_.totalStaked + amount;
        positionState_.amountStaked = positionState_.amountStaked + amount;

        // Store the new positionState and assetState.
        positionState[positionId] = positionState_;
        assetState[positionState_.asset] = assetState_;

        // Stake Asset in external staking contract.
        ERC20(positionState_.asset).safeTransferFrom(msg.sender, address(this), amount);
        _stake(positionState_.asset, amount);

        emit LiquidityIncreased(msg.sender, positionId, positionState_.asset, amount);
    }

    /**
     * @notice Unstakes, withdraws and claims rewards for total amount staked of Asset in position.
     * @param positionId The id of the position to burn.
     */
    function burn(uint256 positionId) external {
        decreaseLiquidity(positionId, positionState[positionId].amountStaked);
    }

    /**
     * @notice Unstakes and withdraws the Asset from the external staking contract.
     * @param positionId The id of the position to withdraw from.
     * @param amount The amount of Asset to unstake and withdraw.
     * @dev Also claims and transfers the staking rewards of the position.
     */
    function decreaseLiquidity(uint256 positionId, uint128 amount) public nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache the old positionState and assetState.
        PositionState memory positionState_ = positionState[positionId];
        AssetState memory assetState_ = assetState[positionState_.asset];

        // Calculate the new reward balances.
        (assetState_, positionState_) = _getRewardBalances(assetState_, positionState_);

        // Calculate the new staked amounts.
        assetState_.totalStaked = assetState_.totalStaked - amount;
        positionState_.amountStaked = positionState_.amountStaked - amount;

        // Rewards are claimed and paid out to the owner on a decreaseLiquidity.
        // -> Reset the balances of the pending rewards for the Asset and the position.
        uint256 rewardPosition = positionState_.lastRewardPosition;
        positionState_.lastRewardPosition = 0;
        assetState_.lastRewardGlobal = 0;

        // Store the new positionState and assetState.
        if (positionState_.amountStaked > 0) {
            positionState[positionId] = positionState_;
        } else {
            _burn(positionId);
        }
        assetState[positionState_.asset] = assetState_;

        // Withdraw the Assets from external staking contract.
        _withdraw(positionState_.asset, amount);

        // Claim the reward from the external staking contract.
        _claimReward(positionState_.asset);

        // Pay out the rewards to the position owner.
        if (rewardPosition > 0) {
            // Cache reward token
            ERC20 rewardToken_ = assetToRewardToken[positionState_.asset];
            // Transfer reward
            rewardToken_.safeTransfer(msg.sender, rewardPosition);
            emit RewardPaid(msg.sender, address(rewardToken_), uint128(rewardPosition));
        }

        // Transfer the Asset back to the position owner.
        ERC20(positionState_.asset).safeTransfer(msg.sender, amount);
        emit LiquidityDecreased(msg.sender, positionState_.asset, amount);
    }

    /**
     * @notice Claims and transfers the staking rewards of the position.
     * @param positionId The id of the position.
     */
    function claimReward(uint256 positionId) external virtual nonReentrant {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache the old positionState and assetState.
        PositionState memory positionState_ = positionState[positionId];
        AssetState memory assetState_ = assetState[positionState_.asset];

        // Calculate the new reward balances.
        (assetState_, positionState_) = _getRewardBalances(assetState_, positionState_);

        // Rewards are claimed and paid out to the owner on a claimReward.
        // -> Reset the balances of the pending rewards for the Asset and the position.
        uint256 rewardPosition = positionState_.lastRewardPosition;
        positionState_.lastRewardPosition = 0;
        assetState_.lastRewardGlobal = 0;

        // Store the new positionState and assetState.
        positionState[positionId] = positionState_;
        assetState[positionState_.asset] = assetState_;

        // Claim the reward from the external staking contract.
        _claimReward(positionState_.asset);

        // Pay out the share of the reward owed to the position owner.
        if (rewardPosition > 0) {
            // Cache reward
            ERC20 rewardToken_ = assetToRewardToken[positionState_.asset];
            // Transfer reward
            rewardToken_.safeTransfer(msg.sender, rewardPosition);
            emit RewardPaid(msg.sender, address(rewardToken_), uint128(rewardPosition));
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
        // Cache the old positionState and assetState.
        PositionState memory positionState_ = positionState[positionId];
        AssetState memory assetState_ = assetState[positionState_.asset];

        // Calculate the new reward balances.
        (, positionState_) = _getRewardBalances(assetState_, positionState_);

        currentRewardClaimable = positionState_.lastRewardPosition;
    }

    /**
     * @notice Calculates the current global and position specific reward balances.
     * @param assetState_ Struct with the old rewards state of the the Asset.
     * @param positionState_ Struct with the old rewards state of the position.
     * @return currentAssetState Struct with the current rewards state of the Asset.
     * @return currentPositionState Struct with the current rewards state of the position.
     */
    function _getRewardBalances(AssetState memory assetState_, PositionState memory positionState_)
        internal
        view
        returns (AssetState memory, PositionState memory)
    {
        if (assetState_.totalStaked > 0) {
            // Calculate the new assetState.
            // Fetch the current reward balance from the staking contract.
            uint256 currentRewardGlobal = _getCurrentReward(positionState_.asset);
            // Calculate the increase in rewards since last contract interaction.
            uint256 deltaReward = currentRewardGlobal - assetState_.lastRewardGlobal;
            // Calculate the new RewardPerToken.
            assetState_.lastRewardPerTokenGlobal =
                uint128(assetState_.lastRewardPerTokenGlobal + deltaReward.mulDivDown(1e18, assetState_.totalStaked));
            assetState_.lastRewardGlobal = uint128(currentRewardGlobal);

            // Calculate the new positionState.
            // Calculate the difference in rewardPerToken since the last position interaction.
            uint256 deltaRewardPerToken =
                assetState_.lastRewardPerTokenGlobal - positionState_.lastRewardPerTokenPosition;
            // Calculate the rewards earned by the position since its last interaction.
            uint256 accruedRewards = deltaRewardPerToken.mulDivDown(positionState_.amountStaked, 1e18);
            positionState_.lastRewardPosition = uint128(positionState_.lastRewardPosition + accruedRewards);
        }
        positionState_.lastRewardPerTokenPosition = assetState_.lastRewardPerTokenGlobal;

        return (assetState_, positionState_);
    }
}
