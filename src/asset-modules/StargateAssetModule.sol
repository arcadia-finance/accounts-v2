/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DerivedAssetModule, FixedPointMathLib, IRegistry } from "./AbstractDerivedAssetModule.sol";
import { IStargatePool } from "./interfaces/IStargatePool.sol";
import { IStargateLpStaking } from "./interfaces/IStargateLpStaking.sol";
import { StakingModule, ERC20 } from "./staking-module/AbstractStakingModule.sol";
import { AssetValueAndRiskFactors } from "../libraries/AssetValuationLib.sol";

/**
 * @title Asset-Module for Stargate Finance pools
 * @author Pragma Labs
 * @notice The StargateAssetModule stores pricing logic and basic information for Stargate Finance LP pools
 * @dev No end-user should directly interact with the StargateAssetModule, only the Registry, the contract owner or via the actionHandler
 */
contract StargateAssetModule is DerivedAssetModule, StakingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The Stargate LP tokens staking contract.
    IStargateLpStaking public immutable stargateLpStaking;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The Unique identifiers of the underlying assets of a Liquidity Position.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;
    // The specific Stargate pool id for an asset.
    mapping(address asset => uint256 poolId) internal assetToPoolId;
    // A mapping from this contract ERC1155 tokens asset keys to it's corresponding stargate LP token asset key.
    mapping(bytes32 erc1155AssetKey => bytes32 lpAssetKey) internal matchERC1155ToAsset;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error UnderlyingAssetNotAllowed();
    error AssetNotAllowed();
    error RewardTokenNotMatching();
    error RewardsOnlyClaimableOnWithdrawal();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param stargateLpStaking_ The address of the Stargate LP staking contract.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC20 tokens is 0.
     */
    constructor(address registry_, IStargateLpStaking stargateLpStaking_) DerivedAssetModule(registry_, 0) {
        stargateLpStaking = stargateLpStaking_;
        // This contract should be added to the Registry to allow ERC1155 tokens minted by this contract.
        IRegistry(REGISTRY).addAsset(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset (Stargate LP Pool) to the StargateAssetModule.
     * @param asset The contract address of the Stargate Pool.
     */
    function addAsset(address asset, uint256 poolId) external onlyOwner {
        address underlyingToken_ = IStargatePool(asset).token();

        // Note: Double check the underlyingToken as for ETH it didn't seem to be the primary asset.
        if (!IRegistry(REGISTRY).isAllowed(underlyingToken_, 0)) revert UnderlyingAssetNotAllowed();

        assetToPoolId[asset] = poolId;
        inAssetModule[asset] = true;

        bytes32[] memory underlyingAssets_ = new bytes32[](1);
        underlyingAssets_[0] = _getKeyFromAsset(underlyingToken_, 0);
        assetToUnderlyingAssets[_getKeyFromAsset(asset, 0)] = underlyingAssets_;

        // Will revert in Registry if asset was already added.
        IRegistry(REGISTRY).addAsset(asset);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * @param asset The contract address of the asset.
     * param assetId The Id of the asset.
     * @return A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256) public view override returns (bool) {
        if (inAssetModule[asset]) return true;
    }

    /**
     * @notice Returns the unique identifier of an asset based on the contract address and id.
     * @param asset The contract address of the asset.
     * @param assetId The id of the asset.
     * @return key The unique identifier.
     * @dev Unsafe bitshift from uint256 to uint96, use only when the ids of the assets cannot exceed type(uint96).max.
     * For asset where the id can be bigger than a uint96, use a mapping of asset and assetId to storage.
     * These assets can however NOT be used as underlying assets (processIndirectDeposit() must revert).
     */
    function _getKeyFromAsset(address asset, uint256 assetId) internal view override returns (bytes32 key) {
        assembly {
            // Shift the assetId to the left by 20 bytes (160 bits).
            // Then OR the result with the address.
            key := or(shl(160, assetId), asset)
        }

        if (asset == address(this)) {
            key = matchERC1155ToAsset[key];
        }
    }

    /**
     * @notice Returns the contract address and id of an asset based on the unique identifier.
     * @param key The unique identifier.
     * @return asset The contract address of the asset.
     * @return assetId The id of the asset.
     */
    function _getAssetFromKey(bytes32 key) internal view override returns (address asset, uint256 assetId) {
        assembly {
            // Shift to the right by 20 bytes (160 bits) to extract the uint96 assetId.
            assetId := shr(160, key)

            // Use bitmask to extract the address from the rightmost 160 bits.
            asset := and(key, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
        }

        if (asset == address(this)) {
            asset = address(underlyingToken[assetId]);
            assetId = 0;
        }
    }

    function _matchAssetKeys(bytes32 assetKey) internal view returns (bytes32 _assetKey) {
        _assetKey = assetKey;
        // Cache value
        bytes32 matchedKey = matchERC1155ToAsset[assetKey];
        if (matchedKey != bytes32(0x0)) {
            _assetKey = matchedKey;
        }
    }

    /**
     * @notice Returns the unique identifiers of the underlying assets.
     * @param assetKey The unique identifier of the asset.
     * @return underlyingAssetKeys The unique identifiers of the underlying assets.
     */
    function _getUnderlyingAssets(bytes32 assetKey)
        internal
        view
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        assetKey = _matchAssetKeys(assetKey);
        underlyingAssetKeys = assetToUnderlyingAssets[assetKey];

        if (underlyingAssetKeys.length == 0) {
            // Only used as an off-chain view function by getValue() to return the value of a non deposited Liquidity Position.
            (address asset,) = _getAssetFromKey(assetKey);
            address underlyingToken_ = IStargatePool(asset).token();

            underlyingAssetKeys = new bytes32[](1);
            underlyingAssetKeys[0] = _getKeyFromAsset(underlyingToken_, 0);
        }
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 assetAmount,
        bytes32[] memory underlyingAssetKeys
    )
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        assetKey = _matchAssetKeys(assetKey);
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        (address asset,) = _getAssetFromKey(assetKey);
        underlyingAssetsAmounts = new uint256[](1);

        // Calculate underlyingAssets amounts
        // "amountSD" is used in Stargate contracts and stands for amount in Shared Decimals, which should be convered to Local Decimals via convertRate.
        uint256 amountSD =
            assetAmount.mulDivDown(IStargatePool(asset).totalLiquidity(), IStargatePool(asset).totalSupply());
        underlyingAssetsAmounts[0] = amountSD * IStargatePool(asset).convertRate();

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /*///////////////////////////////////////////////////////////////
                        STAKING TOKEN MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new staking token with it's corresponding reward token.
     * @param asset The contract address of the Stargate LP token.
     * @param rewardToken_ The contract address of the reward token.
     */
    function addNewStakingToken(address asset, address rewardToken_) public override {
        if (tokenToRewardToId[asset][rewardToken_] != 0) revert TokenToRewardPairAlreadySet();

        if (!isAllowed(asset, 0)) revert AssetNotAllowed();

        if (address(stargateLpStaking.eToken()) != rewardToken_) revert RewardTokenNotMatching();

        // Note: think this is already checked when adding an asset
        if (ERC20(asset).decimals() > 18 || ERC20(rewardToken_).decimals() > 18) revert InvalidTokenDecimals();

        // Cache new id
        uint256 newId;
        unchecked {
            newId = ++lastId;
        }

        // Note: Think it makes more sense to rename to stakingToken for the case when it's the asset that is staked directly.
        underlyingToken[newId] = ERC20(asset);
        rewardToken[newId] = ERC20(rewardToken_);
        tokenToRewardToId[asset][rewardToken_] = newId;

        // Map the assetKey of the new ERC1155 token id to it's corresponding LP token assetKey.
        bytes32 erc1155AssetKey = _getKeyFromAsset(address(this), newId);
        bytes32 lpTokenAssetKey = _getKeyFromAsset(asset, 0);
        matchERC1155ToAsset[erc1155AssetKey] = lpTokenAssetKey;
    }

    /*///////////////////////////////////////////////////////////////
                    STAKING MODULE LOGIC
    ///////////////////////////////////////////////////////////////*/

    function claimReward(uint256) external pure override {
        revert RewardsOnlyClaimableOnWithdrawal();
    }

    /*///////////////////////////////////////////////////////////////
                    INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens in the external staking contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to stake.
     */
    function _stake(uint256 id, uint256 amount) internal override {
        ERC20 asset = underlyingToken[id];
        asset.approve(address(stargateLpStaking), amount);

        // Stake asset
        stargateLpStaking.deposit(assetToPoolId[address(asset)], amount);
    }

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(uint256 id, uint256 amount) internal override {
        ERC20 asset = underlyingToken[id];

        // Withdraw asset
        stargateLpStaking.withdraw(assetToPoolId[address(asset)], amount);
    }

    /**
     * @notice Claims the rewards available for this contract.
     * @param id The id of the specific staking token.
     * @dev This function is left empty as there is no method on Stargate contract to claim rewards separately. Accounts have to withdraw in order to claim rewards.
     */
    function _claimReward(uint256 id) internal override { }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract.
     * @param id The id of the specific staking token.
     * @return currentReward The amount of rewards tokens that can be claimed.
     */
    function _getCurrentReward(uint256 id) internal view override returns (uint256 currentReward) {
        ERC20 asset = underlyingToken[id];
        currentReward = stargateLpStaking.pendingEmissionToken(assetToPoolId[address(asset)], address(this));
    }

    /*///////////////////////////////////////////////////////////////
                           ERC1155 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Function that returns the URI as defined in the ERC1155 standard.
     * @param id The id of the specific staking token.
     * @return uri The token URI.
     */
    function uri(uint256 id) public view override returns (string memory) { }
}
