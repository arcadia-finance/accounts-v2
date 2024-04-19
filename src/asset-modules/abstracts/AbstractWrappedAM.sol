/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../lib/solmate/src/tokens/ERC721.sol";
import { DerivedAM, FixedPointMathLib, IRegistry } from "./AbstractDerivedAM.sol";
import { ReentrancyGuard } from "../../../lib/solmate/src/utils/ReentrancyGuard.sol";
import { SafeCastLib } from "../../../lib/solmate/src/utils/SafeCastLib.sol";
import { SafeTransferLib } from "../../../lib/solmate/src/utils/SafeTransferLib.sol";
import { Strings } from "../../libraries/Strings.sol";

/**
 * @title Wrapped Module
 * @author Pragma Labs
 * @notice Abstract contract with the minimal implementation of a wrapper contract for assets that are earning multiple rewards.
 * @dev This contract will make use of custom assets, which represent a specific combination of an Asset with rewards claimbable for that Asset. To generate the address of a custom asset, an Asset address is hashed together with rewards addresses using keccak256 hash function, and converted to an address. The address generated will be the address of the custom asset.
 * @dev The wrapped Module is an ERC721 contract that does the accounting per Asset, custom Asset and per position owner for:
 *  - The balances of Assets wrapped through this contract.
 *  - The balances of reward tokens earned for custom assets.
 * Next to keeping the accounting of balances, this contract manages the interactions with the external rewards contract in order to claim pending rewards.
 */
abstract contract WrappedAM is DerivedAM, ERC721, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using Strings for uint256;
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The max amount of rewards that should ever be allowed.
    uint8 public immutable MAX_REWARDS = 10;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The id of last minted position.
    uint256 internal lastPositionId;

    // The baseURI of the ERC721 tokens.
    string public baseURI;

    // Max rewards
    uint256 public maxRewardsPerAsset;

    // Map an Asset to its underlying asset
    mapping(address asset => address underlyingAsset) public assetToUnderlyingAsset;
    // Map a position id to its corresponding struct with the position state.
    mapping(uint256 position => PositionState) public positionState;
    // Map a position to a reward and to its corresponding reward state.
    mapping(uint256 position => mapping(address reward => RewardStatePosition)) public rewardStatePosition;
    // Map a customAsset to its underlying asset and rewards.
    mapping(address customAsset => AssetAndRewards) public customAssetInfo;
    // Map an Asset to a reward token and to its lastRewardPerTokenGlobal at last time of interaction.
    mapping(address asset => mapping(address rewardToken => uint128 lastRewardPerTokenGlobal)) public
        lastRewardPerTokenGlobal;
    // Map an Asset to total amount wrapped in this Asset Module.
    mapping(address asset => uint128 totalWrapped) public assetToTotalWrapped;
    // Map an Asset to all reward tokens claimable for that asset via this Asset Module.
    mapping(address asset => address[] rewards) public rewardsForAsset;

    // Struct with the Position specific state.
    struct PositionState {
        // A hash of a combination of Asset and rewards.
        address customAsset;
        // Total amount of Asset wrapped for this position.
        uint128 amountWrapped;
    }

    struct RewardStatePosition {
        // The growth of reward tokens per Asset wrapped, at the last interaction of the position owner with this contract,
        // with 18 decimals precision.
        uint128 lastRewardPerTokenPosition;
        // The unclaimed amount of reward tokens of the position owner, at the last interaction of the owner with this contract.
        uint128 lastRewardPosition;
    }

    struct AssetAndRewards {
        // Flag indicating if the asset is allowed.
        bool allowed;
        // The contract address of the Asset.
        address asset;
        // An array of rewards claimable by the owner of a custom Asset.
        address[] rewards;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event LiquidityDecreased(uint256 indexed positionId, address indexed asset, uint128 amount);
    event LiquidityIncreased(uint256 indexed positionId, address indexed asset, uint128 amount);
    event RewardPaid(uint256 indexed positionId, address indexed reward, uint128 amount);

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetNotAllowed();
    error NotOwner();
    error ZeroAmount();
    error MaxRewardsReached();
    error IncreaseRewardsOnly();

    /* //////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry The contract address of the Registry.
     * @param name_ Name of the Wrapper Module.
     * @param symbol_ Symbol of the Wrapper Module.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for ERC721 tokens.
     */
    constructor(address registry, string memory name_, string memory symbol_)
        DerivedAM(registry, 2)
        ERC721(name_, symbol_)
    { }

    /* //////////////////////////////////////////////////////////////
                               INITIALIZE
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will add this contract as an asset in the Registry.
     * @param maxRewardsPerAsset_ The maximum amount of rewards that can be accounted for an Asset.
     * @dev Will revert if called more than once.
     */
    function initialize(uint8 maxRewardsPerAsset_) external onlyOwner {
        inAssetModule[address(this)] = true;
        maxRewardsPerAsset = maxRewardsPerAsset_;

        IRegistry(REGISTRY).addAsset(uint96(ASSET_TYPE), address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds an asset that can be wrapped through this contract.
     * @param customAsset The contract address of the custom Asset.
     * @param asset_ The contract address of the Asset.
     * @param rewards_ An array with all reward addresses for a specific custom Asset.
     */
    function _addAsset(address customAsset, address asset_, address[] memory rewards_) internal {
        if (rewards_.length > maxRewardsPerAsset) revert MaxRewardsReached();

        customAssetInfo[customAsset] = AssetAndRewards({ allowed: true, asset: asset_, rewards: rewards_ });

        // Cache current rewards tracked for an Asset
        address[] memory currentRewardsForAsset = rewardsForAsset[asset_];

        // Check for new rewards available for an asset and add those to "rewardsForAsset"
        if (currentRewardsForAsset.length == 0) {
            rewardsForAsset[asset_] = rewards_;
        } else {
            for (uint256 i; i < rewards_.length; ++i) {
                bool isNew = true;
                for (uint256 j; j < currentRewardsForAsset.length; ++j) {
                    if (rewards_[i] == currentRewardsForAsset[j]) {
                        isNew = false;
                    }
                }
                if (isNew == true && currentRewardsForAsset.length < maxRewardsPerAsset) {
                    rewardsForAsset[asset_].push(rewards_[i]);
                } else if (isNew == true && currentRewardsForAsset.length == maxRewardsPerAsset) {
                    revert MaxRewardsReached();
                }
            }
        }
    }

    /**
     * @notice Sets the max number of rewards that can be accounted for an Asset.
     * @param maxRewards The new max number of rewards that can be accounted for an Asset.
     */
    function setMaxRewardsPerAsset(uint256 maxRewards) external onlyOwner {
        if (maxRewards > MAX_REWARDS) revert MaxRewardsReached();
        if (maxRewards <= maxRewardsPerAsset) revert IncreaseRewardsOnly();
        maxRewardsPerAsset = maxRewards;
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return allowed A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256 assetId) public view override returns (bool allowed) {
        if (asset == address(this) && assetId <= lastPositionId) allowed = true;
    }

    /**
     * @notice Returns the unique identifiers of the underlying assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the underlying assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        virtual
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        (, uint256 positionId) = _getAssetFromKey(assetKey);
        AssetAndRewards memory assetAndRewards = customAssetInfo[positionState[positionId].customAsset];

        address underlyingAsset = assetToUnderlyingAsset[assetAndRewards.asset];
        uint256 numberOfUnderlyingAssets = assetAndRewards.rewards.length + 1;

        underlyingAssetKeys = new bytes32[](numberOfUnderlyingAssets);
        underlyingAssetKeys[0] = _getKeyFromAsset(underlyingAsset, 0);
        for (uint256 i = 1; i < numberOfUnderlyingAssets; ++i) {
            underlyingAssetKeys[i] = _getKeyFromAsset(assetAndRewards.rewards[i - 1], 0);
        }
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param amount The amount of the Asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(address, bytes32 assetKey, uint256 amount, bytes32[] memory)
        internal
        view
        virtual
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        (, uint256 positionId) = _getAssetFromKey(assetKey);

        // Cache values
        address customAsset = positionState[positionId].customAsset;
        address asset = customAssetInfo[customAsset].asset;
        address[] memory activeRewards = rewardsForAsset[asset];
        AssetAndRewards memory customAssetAndRewards = customAssetInfo[customAsset];
        uint256 numberOfUnderlyingAssets = customAssetAndRewards.rewards.length + 1;

        // Amount of a Wrapped position in the Asset Module can only be either 0 or 1.
        if (amount == 0) return (new uint256[](numberOfUnderlyingAssets), rateUnderlyingAssetsToUsd);

        // Isolate rewards that account as underlyingAsset for a customAsset.
        uint256[] memory rewardsClaimable = rewardsOf(positionId);
        uint256[] memory underlyingRewardsAmount = new uint256[](customAssetAndRewards.rewards.length);
        for (uint256 i; i < customAssetAndRewards.rewards.length; ++i) {
            address underlyingReward = customAssetAndRewards.rewards[i];
            for (uint256 j; j < activeRewards.length; ++j) {
                if (underlyingReward == activeRewards[j]) {
                    underlyingRewardsAmount[i] = rewardsClaimable[j];
                }
            }
        }

        underlyingAssetsAmounts = new uint256[](numberOfUnderlyingAssets);
        underlyingAssetsAmounts[0] = positionState[positionId].amountWrapped;
        for (uint256 i = 1; i < numberOfUnderlyingAssets; ++i) {
            underlyingAssetsAmounts[i] = underlyingRewardsAmount[i - 1];
        }

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the risk factors of an asset for a Creditor.
     * @param creditor The contract address of the Creditor.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return collateralFactor The collateral factor of the asset for the Creditor, 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for the Creditor, 4 decimals precision.
     */
    function getRiskFactors(address creditor, address asset, uint256 assetId)
        external
        view
        virtual
        override
        returns (uint16 collateralFactor, uint16 liquidationFactor)
    {
        bytes32 assetKey = _getKeyFromAsset(asset, assetId);
        bytes32[] memory underlyingAssetKeys = _getUnderlyingAssets(assetKey);

        uint256[] memory underlyingAssetsAmounts;
        (underlyingAssetsAmounts,) = _getUnderlyingAssetsAmounts(creditor, assetKey, 1, underlyingAssetKeys);
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd =
            _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        (, uint256 collateralFactor_, uint256 liquidationFactor_) =
            _calculateValueAndRiskFactors(creditor, underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);

        // Unsafe cast: collateralFactor_ and liquidationFactor_ are smaller than or equal to 1e4.
        return (uint16(collateralFactor_), uint16(liquidationFactor_));
    }

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @param rateUnderlyingAssetsToUsd The USD rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     * @return valueInUsd The value of the asset denominated in USD, with 18 Decimals precision.
     * @return collateralFactor The collateral factor of the asset for a given Creditor, with 4 decimals precision.
     * @return liquidationFactor The liquidation factor of the asset for a given Creditor, with 4 decimals precision.
     * @dev We take a weighted risk factor of underlying assets.
     */
    function _calculateValueAndRiskFactors(
        address creditor,
        uint256[] memory underlyingAssetsAmounts,
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd
    )
        internal
        view
        virtual
        override
        returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor)
    {
        // "rateUnderlyingAssetsToUsd" is the USD value with 18 decimals precision for 10**18 tokens of Underlying Asset.
        // To get the USD value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
        // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
        uint256[] memory assetValues = new uint256[](underlyingAssetsAmounts.length);
        for (uint256 i; i < underlyingAssetsAmounts.length; ++i) {
            assetValues[i] += underlyingAssetsAmounts[i].mulDivDown(rateUnderlyingAssetsToUsd[i].assetValue, 1e18);

            valueInUsd += assetValues[i];
        }

        // Calculate weighted risk factors.
        if (valueInUsd > 0) {
            unchecked {
                for (uint256 i; i < underlyingAssetsAmounts.length; ++i) {
                    collateralFactor += assetValues[i] * rateUnderlyingAssetsToUsd[i].collateralFactor;

                    liquidationFactor += assetValues[i] * rateUnderlyingAssetsToUsd[i].liquidationFactor;
                }
                collateralFactor /= valueInUsd;
                liquidationFactor /= valueInUsd;
            }
        }

        // Lower risk factors with the protocol wide risk factor.
        uint256 riskFactor = riskParams[creditor].riskFactor;
        collateralFactor = riskFactor.mulDivDown(collateralFactor, AssetValuationLib.ONE_4);
        liquidationFactor = riskFactor.mulDivDown(liquidationFactor, AssetValuationLib.ONE_4);
    }

    /*///////////////////////////////////////////////////////////////
                         WRAPPER MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Wraps an amount of Assets in this contract and mints a new position.
     * @param customAsset The contract address of the asset to wrap.
     * @param amount The amount of Assets to wrap.
     * @return positionId The id of the minted position.
     */
    function mint(address customAsset, uint128 amount) external virtual nonReentrant returns (uint256 positionId) {
        if (amount == 0) revert ZeroAmount();

        // Cache struct
        AssetAndRewards memory customAssetInfo_ = customAssetInfo[customAsset];

        // Need to transfer before minting or ERC777s could reenter.
        ERC20(customAssetInfo_.asset).safeTransferFrom(msg.sender, address(this), amount);
        if (!customAssetInfo_.allowed) revert AssetNotAllowed();

        unchecked {
            positionId = ++lastPositionId;
        }

        // Set customAsset for position
        positionState[positionId].customAsset = customAsset;

        // Set lastRewardPerPosition for each reward
        (uint128[] memory lastRewardPerTokenGlobalArr,, address[] memory activeRewards) = _getRewardBalances(positionId);

        // Update the new wrapped amounts and set positionState
        assetToTotalWrapped[customAssetInfo_.asset] = assetToTotalWrapped[customAssetInfo_.asset] + amount;
        positionState[positionId].amountWrapped = amount;

        for (uint256 i; i < activeRewards.length; ++i) {
            rewardStatePosition[positionId][activeRewards[i]].lastRewardPerTokenPosition =
                lastRewardPerTokenGlobalArr[i];
        }

        // Mint the new position.
        _safeMint(msg.sender, positionId);

        // TODO: Log asset or customAsset here ?
        emit LiquidityIncreased(positionId, customAssetInfo_.asset, amount);
    }

    /**
     * @notice Wraps additional Assets for an existing position.
     * @param positionId The id of the position.
     * @param amount The amount of Assets to wrap.
     */
    function increaseLiquidity(uint256 positionId, uint128 amount) external virtual nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache asset
        address asset = customAssetInfo[positionState[positionId].customAsset].asset;

        // Need to transfer before increasing liquidity or ERC777s could reenter.
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Update rewardState for position (lastRewardPerTokenPosition + lastRewardPosition)
        (, RewardStatePosition[] memory rewardStatePositionArr, address[] memory activeRewards) =
            _getRewardBalances(positionId);

        for (uint256 i; i < activeRewards.length; ++i) {
            rewardStatePosition[positionId][activeRewards[i]] = rewardStatePositionArr[i];
        }

        // Calculate the updated wrapped amounts.
        positionState[positionId].amountWrapped = positionState[positionId].amountWrapped + amount;
        assetToTotalWrapped[asset] = assetToTotalWrapped[asset] + amount;

        emit LiquidityIncreased(positionId, asset, amount);
    }

    /**
     * @notice Unwraps, withdraws and claims rewards for total amount of wrapped Asset in position.
     * @param positionId The id of the position to burn.
     */
    function burn(uint256 positionId) public virtual returns (uint256[] memory rewards) {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache position amount
        uint256 positionAmount = positionState[positionId].amountWrapped;

        // Claim rewards before burning the position
        (rewards) = claimRewards(positionId);

        // Cache values.
        address asset = customAssetInfo[positionState[positionId].customAsset].asset;
        address[] memory activeRewards = rewardsForAsset[asset];

        // Delete mappings
        delete positionState[positionId];
        for (uint256 i; i < activeRewards.length; ++i) {
            delete rewardStatePosition[positionId][activeRewards[i]];
        }

        _burn(positionId);

        // Transfer the asset back to the position owner.
        ERC20(asset).safeTransfer(msg.sender, positionAmount);
        emit LiquidityDecreased(positionId, asset, uint128(positionAmount));
    }

    /**
     * @notice Unwraps and withdraws the asset from this contract.
     * @param positionId The id of the position to withdraw from.
     * @param amount The amount of Asset to unwrap and withdraw.
     * @return rewards The amount of reward tokens claimed.
     */
    function decreaseLiquidity(uint256 positionId, uint128 amount)
        public
        virtual
        nonReentrant
        returns (uint256[] memory rewards)
    {
        if (amount == 0) revert ZeroAmount();

        if (positionState[positionId].amountWrapped == amount) {
            rewards = burn(positionId);
        } else {
            if (_ownerOf[positionId] != msg.sender) revert NotOwner();

            // Cache asset.
            address asset = customAssetInfo[positionState[positionId].customAsset].asset;

            // Calculate the new reward balances.
            (, RewardStatePosition[] memory rewardStatePositionArr, address[] memory activeRewards) =
                _getRewardBalances(positionId);

            // Update the reward state
            for (uint256 i; i < activeRewards.length; ++i) {
                rewardStatePosition[positionId][activeRewards[i]] = rewardStatePositionArr[i];
            }

            // Calculate the updated wrapped amounts.
            positionState[positionId].amountWrapped = positionState[positionId].amountWrapped - amount;
            assetToTotalWrapped[asset] = assetToTotalWrapped[asset] - amount;

            // Transfer the asset back to the position owner.
            ERC20(asset).safeTransfer(msg.sender, amount);
            emit LiquidityDecreased(positionId, asset, amount);
        }
    }

    /**
     * @notice Claims and transfers the rewards of the position.
     * @param positionId The id of the position.
     * @return rewards The amount of reward tokens claimed.
     */
    function claimRewards(uint256 positionId) public virtual nonReentrant returns (uint256[] memory rewards) {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache asset
        address asset = customAssetInfo[positionState[positionId].customAsset].asset;

        // Calculate the new reward balances.
        (
            uint128[] memory lastRewardPerTokenGlobalArr,
            RewardStatePosition[] memory rewardStatePositionArr,
            address[] memory activeRewards_
        ) = _getRewardBalances(positionId);

        rewards = new uint256[](activeRewards_.length);
        // Store the new rewardState and lastRewardPerTokenGlobal
        for (uint256 i; i < activeRewards_.length; ++i) {
            rewards[i] = rewardStatePositionArr[i].lastRewardPosition;
            // Rewards are paid out to the owner on a claimReward.
            rewardStatePositionArr[i].lastRewardPosition = 0;
            // Store the new rewardStatePosition
            rewardStatePosition[positionId][activeRewards_[i]] = rewardStatePositionArr[i];
            // Store the new value of lastRewardPerTokenGlobal
            lastRewardPerTokenGlobal[asset][activeRewards_[i]] = lastRewardPerTokenGlobalArr[i];
        }

        // Claim the pending rewards from the external contract.
        // TODO : double check
        _claimRewards(asset, activeRewards_);

        // Pay out the share of the reward owed to the position owner.
        for (uint256 i = 0; i < activeRewards_.length; ++i) {
            if (rewards[i] > 0) {
                // Transfer reward
                ERC20(activeRewards_[i]).safeTransfer(msg.sender, rewards[i]);
                emit RewardPaid(positionId, activeRewards_[i], uint128(rewards[i]));
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                    INTERACTIONS REWARD CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The Asset for which rewards will be claimed.
     * @param rewards The active rewards in this contract to claim.
     */
    function _claimRewards(address asset, address[] memory rewards) internal virtual;

    /**
     * @notice Returns the amount of reward tokens that can be claimed for a specific Asset by this contract.
     * @param asset The Asset that is earning rewards.
     * @param rewards The reward earned by the Asset.
     * @return currentRewards The amount of rewards tokens that can be claimed.
     */
    function _getCurrentRewards(address asset, address[] memory rewards)
        internal
        view
        virtual
        returns (uint256[] memory currentRewards);

    /*///////////////////////////////////////////////////////////////
                         REWARDS VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the array of reward tokens claimable by a custom Asset.
     * @param customAsset The address of the custom Asset.
     * @return rewards An array of reward addresses claimable by a specific customAsset wrapped through this AM.
     */
    function getRewardsForCustomAsset(address customAsset) external view returns (address[] memory rewards) {
        rewards = customAssetInfo[customAsset].rewards;
    }

    /**
     * @notice Returns the amount of reward tokens claimable by a position.
     * @param positionId The id of the position to check the rewards for.
     * @return currentRewardsClaimable An array of current amount of reward tokens claimable by the owner of the position.
     */
    function rewardsOf(uint256 positionId) public view virtual returns (uint256[] memory currentRewardsClaimable) {
        (, RewardStatePosition[] memory rewardStatePosition_,) = _getRewardBalances(positionId);

        currentRewardsClaimable = new uint256[](rewardStatePosition_.length);
        for (uint256 i; i < rewardStatePosition_.length; ++i) {
            currentRewardsClaimable[i] = rewardStatePosition_[i].lastRewardPosition;
        }
    }

    /**
     * @notice Calculates the current global and position specific reward balances.
     * @param positionId The id of the position to get the reward balances for.
     * @return lastRewardPerTokenGlobalArr An array representing the reward tokens growth per asset wrapped at last interaction with external rewards contract.
     * @return An array of the updated reward state for each reward of a position.
     * @return activeRewards_ An array of all rewards claimable for an asset via this contract.
     */
    function _getRewardBalances(uint256 positionId)
        internal
        view
        returns (
            uint128[] memory lastRewardPerTokenGlobalArr,
            RewardStatePosition[] memory,
            address[] memory activeRewards_
        )
    {
        // Cache asset
        address asset = customAssetInfo[positionState[positionId].customAsset].asset;
        // Cache all active rewards for a given asset
        activeRewards_ = rewardsForAsset[asset];
        // Cache number of active rewards
        uint256 numberOfActiveRewards = activeRewards_.length;
        // Cache total wrapped
        uint256 totalWrapped = assetToTotalWrapped[asset];

        RewardStatePosition[] memory rewardStatePositionArr = new RewardStatePosition[](numberOfActiveRewards);

        // Get the rewardState for each active reward per position
        for (uint256 i; i < numberOfActiveRewards; ++i) {
            rewardStatePositionArr[i] = rewardStatePosition[positionId][activeRewards_[i]];
        }

        lastRewardPerTokenGlobalArr = new uint128[](numberOfActiveRewards);
        uint256[] memory currentRewardsClaimable = _getCurrentRewards(asset, activeRewards_);

        if (totalWrapped > 0) {
            for (uint256 i; i < numberOfActiveRewards; ++i) {
                // Calculate the new assetState
                // Fetch the current reward balance from the reward contract and calculate the change in RewardPerToken.
                uint256 deltaRewardPerToken = currentRewardsClaimable[i].mulDivDown(1e18, totalWrapped);

                // Calculate and update the new RewardPerToken of the asset.
                // unchecked: RewardPerToken can overflow, what matters is the delta in RewardPerToken between two interactions.
                unchecked {
                    lastRewardPerTokenGlobalArr[i] = lastRewardPerTokenGlobal[asset][activeRewards_[i]]
                        + SafeCastLib.safeCastTo128(deltaRewardPerToken);
                }

                // Calculate the new rewardState for the position.
                // Calculate the difference in rewardPerToken since the last position interaction.
                // unchecked: RewardPerToken can underflow, what matters is the delta in RewardPerToken between two interactions.
                // If lastRewardPerTokenPosition == 0, it means a new reward token has been added, no rewards should be added.
                if (rewardStatePositionArr[i].lastRewardPerTokenPosition == 0) {
                    continue;
                } else {
                    unchecked {
                        deltaRewardPerToken =
                            lastRewardPerTokenGlobalArr[i] - rewardStatePositionArr[i].lastRewardPerTokenPosition;
                    }

                    // Calculate the rewards earned by the position since its last interaction.
                    // TODO: double check here : unchecked: deltaRewardPerToken and positionAmount are smaller than type(uint128).max.
                    uint256 deltaReward;
                    unchecked {
                        deltaReward = deltaRewardPerToken * positionState[positionId].amountWrapped / 1e18;
                    }

                    // Update the reward balance of the position.
                    rewardStatePositionArr[i].lastRewardPosition =
                        SafeCastLib.safeCastTo128(rewardStatePositionArr[i].lastRewardPosition + deltaReward);
                }
            }
        } else {
            // If totalWrapped is 0, then lastRewardPerTokenPosition should be equal to lastRewardPerTokenGlobal
            for (uint256 i; i < numberOfActiveRewards; ++i) {
                lastRewardPerTokenGlobalArr[i] = lastRewardPerTokenGlobal[asset][activeRewards_[i]];
            }
        }

        // Update the RewardPerToken of the rewards of the position.
        for (uint256 i; i < numberOfActiveRewards; ++i) {
            rewardStatePositionArr[i].lastRewardPerTokenPosition = lastRewardPerTokenGlobalArr[i];
        }

        return (lastRewardPerTokenGlobalArr, rewardStatePositionArr, activeRewards_);
    }

    /*///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that stores a new base URI.
     * @param newBaseURI The new base URI to store.
     */
    function setBaseURI(string calldata newBaseURI) external virtual onlyOwner {
        baseURI = newBaseURI;
    }

    /**
     * @notice Function that returns the token URI as defined in the ERC721 standard.
     * @param tokenId The id of the Account.
     * @return uri The token URI.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory uri) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }
}
