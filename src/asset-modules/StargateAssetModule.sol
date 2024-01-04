/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DerivedAssetModule, FixedPointMathLib, IRegistry } from "./AbstractDerivedAssetModule.sol";
import { IPool } from "./interfaces/stargate/IPool.sol";
import { ILpStakingTime } from "./interfaces/stargate/ILpStakingTime.sol";
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
    ILpStakingTime public immutable lpStakingTime;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps this contract's ERC1155 assetKeys to the keys of their underlying asset.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;
    // The pool id as referred to in the Stargate "lpStakingTime.sol" contract relative to the underlying asset of the ERC1155 token id.
    mapping(uint256 tokenId => uint256 poolId) public tokenIdToPoolId;
    // Maps this contract's ERC1155 assetKeys to their underlying Stargate pool address.
    mapping(bytes32 assetKey => address pool) internal assetKeyToPool;
    // Maps a token id to a boolean indicating if the token id is allowed.
    mapping(uint256 id => bool allowed) public allowedTokenId;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetNotAllowed();
    error RewardsOnlyClaimableOnWithdrawal();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param lpStakingTime_ The address of the Stargate LP staking contract.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC1155 tokens is 2.
     */
    constructor(address registry_, address lpStakingTime_) DerivedAssetModule(registry_, 2) {
        lpStakingTime = ILpStakingTime(lpStakingTime_);
    }

    /* //////////////////////////////////////////////////////////////
                               INITIALIZE
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will add this contract as an asset in the Registry.
     * @dev Will revert if called more than once.
     */
    function initialize() external onlyOwner {
        IRegistry(REGISTRY).addAsset(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                            ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset (ERC1155 tokenId and it's corresponding Stargate Pool LP) to the StargateAssetModule.
     * @param tokenId The ERC1155 token id of this contract.
     * @param lpStakingPoolId The pool id relative to the underlying asset of "tokenId" in Stargate "lpStakingTime.sol" contract.
     * @param stargatePool The address of the Stargate pool.
     */
    function _addAsset(uint256 tokenId, uint256 lpStakingPoolId, address stargatePool) internal {
        address poolUnderlyingToken = IPool(stargatePool).token();

        if (!IRegistry(REGISTRY).isAllowed(poolUnderlyingToken, 0)) revert AssetNotAllowed();

        bytes32 assetKey = _getKeyFromAsset(address(this), tokenId);

        assetKeyToPool[assetKey] = stargatePool;
        tokenIdToPoolId[tokenId] = lpStakingPoolId;
        allowedTokenId[tokenId] = true;

        bytes32[] memory underlyingAssets_ = new bytes32[](1);
        underlyingAssets_[0] = _getKeyFromAsset(poolUnderlyingToken, 0);
        assetToUnderlyingAssets[assetKey] = underlyingAssets_;
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding Id if it is allowed.
     * param asset The contract address of the asset.
     * @param assetId The Id of the asset.
     * @return allowed A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address, uint256 assetId) public view override returns (bool allowed) {
        allowed = allowedTokenId[assetId];
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
        underlyingAssetKeys = assetToUnderlyingAssets[assetKey];
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
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        address poolLpToken = assetKeyToPool[assetKey];
        underlyingAssetsAmounts = new uint256[](1);

        // Cache totalLiquidity
        uint256 totalLiquidity = IPool(poolLpToken).totalLiquidity();

        // Calculate underlyingAssets amounts.
        // "amountSD" is used in Stargate contracts and stands for amount in Shared Decimals, which should be convered to Local Decimals via convertRate().
        // "amountSD" will always be smaller or equal to amount in Local Decimals.
        uint256 amountSD =
            totalLiquidity != 0 ? assetAmount.mulDivDown(totalLiquidity, IPool(poolLpToken).totalSupply()) : 0;

        underlyingAssetsAmounts[0] = amountSD * IPool(poolLpToken).convertRate();

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /*///////////////////////////////////////////////////////////////
                        STAKING TOKEN MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new staking token with it's corresponding reward token.
     * @param stargatePool The contract address of the Stargate pool.
     * @param lpStakingPoolId The pool id relative to the underlying asset of "tokenId" in Stargate "lpStakingTime.sol" contract.
     */
    function addNewStakingToken(address stargatePool, uint256 lpStakingPoolId) external onlyOwner {
        // Cache addresses
        address rewardToken_ = address(lpStakingTime.eToken());

        uint256 tokenId = _addNewStakingToken(stargatePool, rewardToken_);
        _addAsset(tokenId, lpStakingPoolId, stargatePool);
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

        if (asset.allowance(address(this), address(lpStakingTime)) < amount) {
            asset.approve(address(lpStakingTime), type(uint256).max);
        }

        // Stake asset
        lpStakingTime.deposit(tokenIdToPoolId[id], amount);
    }

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(uint256 id, uint256 amount) internal override {
        // Withdraw asset
        lpStakingTime.withdraw(tokenIdToPoolId[id], amount);
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
        currentReward = lpStakingTime.pendingEmissionToken(tokenIdToPoolId[id], address(this));
    }
}
