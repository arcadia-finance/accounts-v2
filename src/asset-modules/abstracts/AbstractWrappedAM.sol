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

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The id of last minted position.
    uint256 internal lastPositionId;

    // The baseURI of the ERC721 tokens.
    string public baseURI;

    // Map an Asset to its underlying asset
    mapping(address asset => address underlyingAsset) public assetToUnderlyingAsset;
    // Map a position id to its corresponding struct with the position state.
    mapping(uint256 position => PositionState) public positionState;
    // Map a position to a reward and to its corresponding reward state.
    mapping(uint256 position => mapping(address reward => RewardStatePosition)) public rewardStatePosition;
    // Map a customAsset to its underlying asset and rewards.
    mapping(address customAsset => AssetAndRewards) public customAssetInfo;
    mapping(address asset => mapping(address rewardToken => uint256 lastRewardPerTokenGlobal)) public
        lastRewardPerTokenGlobal;
    mapping(address asset => uint256 totalWrapped) public assetToTotalWrapped;
    // TODO: when adding an asset always check if have to update activeRewardsForAsset.
    mapping(address asset => address[] rewards) public activeRewardsForAsset;

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
     * @dev Will revert if called more than once.
     */
    function initialize() external onlyOwner {
        inAssetModule[address(this)] = true;

        IRegistry(REGISTRY).addAsset(uint96(ASSET_TYPE), address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds an asset that can be staked to this contract.
     * @param customAsset The contract address of the custom Asset.
     */
    function _addAsset(address customAsset) internal {
        customAssetInfo[customAsset].allowed = true;
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

        AssetAndRewards memory assetAndRewards = customAssetInfo[positionState[positionId].customAsset];

        uint256 numberOfUnderlyingAssets = assetAndRewards.rewards.length + 1;

        // Amount of a Staked position in the Asset Module can only be either 0 or 1.
        if (amount == 0) return (new uint256[](numberOfUnderlyingAssets), rateUnderlyingAssetsToUsd);

        underlyingAssetsAmounts = new uint256[](numberOfUnderlyingAssets);
        underlyingAssetsAmounts[0] = positionState[positionId].amountWrapped;

        underlyingAssetsAmounts[1] = rewardOf(positionId);

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
     * @dev We take a weighted risk factor of both underlying assets.
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
        uint256 valueStakedAsset = underlyingAssetsAmounts[0].mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, 1e18);
        uint256 valueRewardAsset = underlyingAssetsAmounts[1].mulDivDown(rateUnderlyingAssetsToUsd[1].assetValue, 1e18);
        valueInUsd = valueStakedAsset + valueRewardAsset;

        // Calculate weighted risk factors.
        if (valueInUsd > 0) {
            unchecked {
                collateralFactor = (
                    valueStakedAsset * rateUnderlyingAssetsToUsd[0].collateralFactor
                        + valueRewardAsset * rateUnderlyingAssetsToUsd[1].collateralFactor
                ) / valueInUsd;
                liquidationFactor = (
                    valueStakedAsset * rateUnderlyingAssetsToUsd[0].liquidationFactor
                        + valueRewardAsset * rateUnderlyingAssetsToUsd[1].liquidationFactor
                ) / valueInUsd;
            }
        }

        // Lower risk factors with the protocol wide risk factor.
        uint256 riskFactor = riskParams[creditor].riskFactor;
        collateralFactor = riskFactor.mulDivDown(collateralFactor, AssetValuationLib.ONE_4);
        liquidationFactor = riskFactor.mulDivDown(liquidationFactor, AssetValuationLib.ONE_4);
    }

    /*///////////////////////////////////////////////////////////////
                         STAKING MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of Assets in the external staking contract and mints a new position.
     * @param customAsset The contract address of the asset to wrap.
     * @param amount The amount of Assets to wrap.
     * @return positionId The id of the minted position.
     */
    function mint(address customAsset, uint128 amount) external virtual nonReentrant returns (uint256 positionId) {
        if (amount == 0) revert ZeroAmount();

        AssetAndRewards memory customAssetInfo_ = customAssetInfo[customAsset];

        // Need to transfer before minting or ERC777s could reenter.
        ERC20(customAssetInfo_.asset).safeTransferFrom(msg.sender, address(this), amount);

        if (!customAssetInfo_.allowed) revert AssetNotAllowed();

        unchecked {
            positionId = ++lastPositionId;
        }

        // TODO: see if a transfer of tokens could trigger a claim but shouldn't be the case

        // Calculate the new wrapped amounts and set positionState
        assetToTotalWrapped[customAssetInfo_.asset] += amount;
        positionState[positionId].amountWrapped = amount;
        positionState[positionId].customAsset = customAsset;

        // Mint the new position.
        _safeMint(msg.sender, positionId);

        emit LiquidityIncreased(positionId, customAssetInfo_.asset, amount);
    }

    /**
     * @notice Stakes additional Assets in the external staking contract for an existing position.
     * @param positionId The id of the position.
     * @param amount The amount of Assets to stake.
     */
    function increaseLiquidity(uint256 positionId, uint128 amount) external virtual nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache the old positionState and assetState.
        PositionState memory positionState_ = positionState[positionId];
        address asset = positionState_.asset;
        AssetState memory assetState_ = assetState[asset];

        // Need to transfer before increasing liquidity or ERC777s could reenter.
        ERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        // Calculate the new reward balances.
        (assetState_, positionState_) = _getRewardBalances(assetState_, positionState_);

        // Calculate the new staked amounts.
        assetState_.totalStaked = assetState_.totalStaked + amount;
        positionState_.amountStaked = positionState_.amountStaked + amount;

        // Store the new positionState and assetState.
        positionState[positionId] = positionState_;
        assetState[asset] = assetState_;

        // Stake Asset in external staking contract and claim any pending rewards.
        _stakeAndClaim(asset, amount);

        emit LiquidityIncreased(positionId, asset, amount);
    }

    /**
     * @notice Unstakes, withdraws and claims rewards for total amount staked of Asset in position.
     * @param positionId The id of the position to burn.
     */
    function burn(uint256 positionId) external virtual {
        decreaseLiquidity(positionId, positionState[positionId].amountStaked);
    }

    /**
     * @notice Unstakes and withdraws the asset from the external staking contract.
     * @param positionId The id of the position to withdraw from.
     * @param amount The amount of Asset to unstake and withdraw.
     * @return rewards The amount of reward tokens claimed.
     * @dev Also claims and transfers the staking rewards of the position.
     */
    function decreaseLiquidity(uint256 positionId, uint128 amount)
        public
        virtual
        nonReentrant
        returns (uint256 rewards)
    {
        if (amount == 0) revert ZeroAmount();
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Cache the old positionState and assetState.
        PositionState memory positionState_ = positionState[positionId];
        address asset = positionState_.asset;
        AssetState memory assetState_ = assetState[asset];

        // Calculate the new reward balances.
        (assetState_, positionState_) = _getRewardBalances(assetState_, positionState_);

        // Calculate the new staked amounts.
        assetState_.totalStaked = assetState_.totalStaked - amount;
        positionState_.amountStaked = positionState_.amountStaked - amount;

        // Rewards are paid out to the owner on a decreaseLiquidity.
        // -> Reset the balances of the pending rewards.
        rewards = positionState_.lastRewardPosition;
        positionState_.lastRewardPosition = 0;

        // Store the new positionState and assetState.
        if (positionState_.amountStaked > 0) {
            positionState[positionId] = positionState_;
        } else {
            delete positionState[positionId];
            _burn(positionId);
        }
        assetState[asset] = assetState_;

        // Withdraw the Assets from external staking contract and claim any pending rewards.
        _withdrawAndClaim(asset, amount);

        // Pay out the rewards to the position owner.
        if (rewards > 0) {
            // Transfer reward
            REWARD_TOKEN.safeTransfer(msg.sender, rewards);
            emit RewardPaid(positionId, address(REWARD_TOKEN), uint128(rewards));
        }

        // Transfer the asset back to the position owner.
        ERC20(asset).safeTransfer(msg.sender, amount);
        emit LiquidityDecreased(positionId, asset, amount);
    }

    /**
     * @notice Claims and transfers the staking rewards of the position.
     * @param positionId The id of the position.
     * @return rewards The amount of reward tokens claimed.
     */
    function claimRewards(uint256 positionId) external virtual nonReentrant returns (uint256[] memory rewards) {
        if (_ownerOf[positionId] != msg.sender) revert NotOwner();

        // Calculate the new reward balances.
        (uint256[] memory lastRewardPerTokenGlobalArr, RewardStatePosition[] memory rewardStatePositionArr, address[] memory activeRewards_) = _getRewardBalances(positionId);

        rewards = new uint256[](activeRewards_.length);
        // Store the new rewardState and lastRewardPerTokenGlobal
        for (uint256 i; i < activeRewards_.length; ++i) {
            rewards[i] = rewardStatePositionArr[i].lastRewardPosiion;
            // Rewards are paid out to the owner on a claimReward.
            rewardStatePositionArr[i].lastRewardPosiion = 0;
            // Store the new rewardStatePosition
            rewardStatePosition[positionId][assetAndRewards.rewards[i]] = rewardStatePositionArr[i];
            // Store the new value of lastRewardPerTokenGlobal
            lastRewardPerTokenGlobal[assetAndReward.asset][assetAndReward.rewards[i]] = lastRewardPerTokenGlobalArr[i];
        }

        // Claim the pending rewards from the external contract.
        // TODO : double check
        _claimRewards(asset, activeRewards);

        // Pay out the share of the reward owed to the position owner.
        for (uint256 i = 0; i < activeRewards.length; ++i) {
            if (rewards[i] > 0) {
                // Transfer reward
                ERC20(activeRewards_[i]).safeTransfer(msg.sender, rewards[i]);
                emit RewardPaid(positionId, activeRewards[i], uint128(rewards[i]));
            }
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
     * @notice Stakes an amount of Asset in the external staking contract and claims pending rewards.
     * @param asset The Asset to stake.
     * @param amount The amount of Asset to stake.
     */
    function _stakeAndClaim(address asset, uint256 amount) internal virtual;

    /**
     * @notice Unstakes and withdraws the Asset from the external contract and claims pending rewards.
     * @param asset The Asset to withdraw.
     * @param amount The amount of Asset to unstake and withdraw.
     */
    function _withdrawAndClaim(address asset, uint256 amount) internal virtual;

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The Asset for which rewards will be claimed.
     * @param rewards The active rewards in this contract to claim.
     */
    function _claimRewards(address asset, address[] memory rewards) internal virtual;

    /**
     * @notice Returns the amount of reward tokens that can be claimed for a specific Asset by this contract.
     * @param asset The Asset that is earning rewards.
     * @param reward The reward earned by the Asset.
     * @return currentReward The amount of rewards tokens that can be claimed.
     */
    function _getCurrentReward(address asset, address reward) internal view virtual returns (uint256 currentReward);

    /*///////////////////////////////////////////////////////////////
                         REWARDS VIEW FUNCTIONS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the amount of reward tokens claimable by a position.
     * @param positionId The id of the position to check the rewards for.
     * @return currentRewardsClaimable An array of current amount of reward tokens claimable by the owner of the position.
     */
    function rewardsOf(uint256 positionId) public view virtual returns (uint256[] memory currentRewardsClaimable) {
        (, RewardStatePosition[] memory rewardStatePosition_,) = _getRewardBalances(positionId);

        currentRewardsClaimable = new uint256[](rewardStatePosition_.length);
        for (uint256 i; i < rewardStatePosition_.length; ++i) {
            currentRewardsClaimable[i] = rewardStatePosition_.lastRewardPosition;
        }
    }

    /**
     * @notice Calculates the current global and position specific reward balances.
     * @param positionId .
     * @return rewardBalances .
     */
    function _getRewardBalances(uint256 positionId)
        internal
        view
        returns (uint256[] memory lastRewardPerTokenGlobalArr, RewardStatePosition[] memory, address[] memory activeRewards_)
    {
        address asset = customAssetInfo[positionState[positionId].customAsset].asset;

        // Cache all active rewards for a given asset
        activeRewards_ = activeRewardsForAsset[asset];
        // Cache number of active rewards
        uint256 numberOfActiveRewards = activeRewards_.length;
        // Cache total wrapped
        uint256 totalWrapped = assetToTotalWrapped[asset];

        RewardStatePosition[] memory rewardStatePositionArr = new RewardStatePosition[](numberOfActiveRewards);

        // Get the rewardState for each active reward per position
        for (uint256 i; i < numberOfActiveRewards; ++i) {
            rewardStatePositionArr[i] = rewardStatePosition[positionId][activeRewards_[i]];
        }

        lastRewardPerTokenGlobalArr = new uint256[](numberOfActiveRewards);

        if (totalWrapped > 0) {
            for (uint256 i; i < numberOfActiveRewards; ++i) {
                // Calculate the new assetState
                // Fetch the current reward balance from the staking contract and calculate the change in RewardPerToken.
                uint256 deltaRewardPerToken =
                    _getCurrentReward(asset, activeRewards[i]).mulDivDown(1e18, totalWrapped);
                // Calculate and update the new RewardPerToken of the asset.
                // unchecked: RewardPerToken can overflow, what matters is the delta in RewardPerToken between two interactions.
                unchecked {
                    lastRewardPerTokenGlobalArr[i] =
                        lastRewardPerTokenGlobal[asset][activeRewards[i]] + deltaRewardPerToken;
                }

                // Calculate the new rewardState for the position.
                // Calculate the difference in rewardPerToken since the last position interaction.
                // unchecked: RewardPerToken can underflow, what matters is the delta in RewardPerToken between two interactions.
                // If lastRewardPerTokenPosition == 0, it means a new reward token has been added, no rewards should be added.
                if (rewardStatePosition_[i].lastRewardPerTokenPosition == 0) {
                    continue;
                } else {
                    unchecked {
                        deltaRewardPerToken =
                            lastRewardPerTokenGlobalArr[i] - rewardStatePosition_[i].lastRewardPerTokenPosition;
                    }

                    // Calculate the rewards earned by the position since its last interaction.
                    // TODO: double check here : unchecked: deltaRewardPerToken and positionAmount are smaller than type(uint128).max.
                    uint256 deltaReward;
                    unchecked {
                        deltaReward = deltaRewardPerToken * positionAmount / 1e18;
                    }
                    // Update the reward balance of the position.
                    rewardStatePosition_[i].lastRewardPosition =
                        SafeCastLib.safeCastTo128(rewardStatePosition_[i].lastRewardPosition + deltaReward);
                }
            }
        }

        // Update the RewardPerToken of the rewards of the position.
        for (uint256 i; i < numberOfActiveRewards; ++i) {
            rewardStatePosition_[i].lastRewardPerTokenPosition = lastRewardPerTokenGlobalArr[i];
        }

        return (lastRewardPerTokenGlobalArr, rewardStatePosition_);
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
