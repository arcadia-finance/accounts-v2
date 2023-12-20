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

    // Maps this contract's ERC1155 assetKeys to the keys of their underlying asset.
    mapping(bytes32 assetKey => bytes32[] underlyingAssetKeys) internal assetToUnderlyingAssets;
    // The specific Stargate pool id relative to the ERC1155 underlying token.
    mapping(uint256 tokenId => uint256 poolId) internal tokenIdToPoolId;
    // Maps this contract's ERC1155 assetKeys to their underlying Stargate pool address.
    mapping(bytes32 assetKey => address pool) internal assetKeyToPool;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

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
    constructor(address registry_, address stargateLpStaking_) DerivedAssetModule(registry_, 2) {
        stargateLpStaking = IStargateLpStaking(stargateLpStaking_);
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
     * @notice Adds a new asset (Stargate LP Pool) to the StargateAssetModule.
     * @param tokenId The ERC1155 token id of this contract.
     * @param stargatePoolId The Stargate pool id relative to the underlying token of "tokenId".
     */
    function addAsset(uint256 tokenId, uint256 stargatePoolId) external onlyOwner {
        address pool = address(underlyingToken[tokenId]);
        address poolUnderlyingToken = IStargatePool(pool).token();

        if (!IRegistry(REGISTRY).isAllowed(poolUnderlyingToken, 0)) revert AssetNotAllowed();

        bytes32 assetKey = _getKeyFromAsset(address(this), tokenId);

        assetKeyToPool[assetKey] = pool;
        tokenIdToPoolId[tokenId] = stargatePoolId;

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
        if (tokenIdToPoolId[assetId] != 0) return true;
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

        if (underlyingAssetKeys.length == 0) {
            // Note: not possible in this case, as the assetKey should be with the address and tokenId of this contract. Thus no data available if not added previously.
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
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        address poolLpToken = assetKeyToPool[assetKey];
        underlyingAssetsAmounts = new uint256[](1);

        // Calculate underlyingAssets amounts
        // "amountSD" is used in Stargate contracts and stands for amount in Shared Decimals, which should be convered to Local Decimals via convertRate.
        uint256 amountSD = assetAmount.mulDivDown(
            IStargatePool(poolLpToken).totalLiquidity(), IStargatePool(poolLpToken).totalSupply()
        );
        underlyingAssetsAmounts[0] = amountSD * IStargatePool(poolLpToken).convertRate();

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /*///////////////////////////////////////////////////////////////
                        STAKING TOKEN MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new staking token with it's corresponding reward token.
     * @param asset The contract address of the Stargate LP token.
     */
    function addNewStakingToken(address asset) external onlyOwner {
        _addNewStakingToken(asset, address(stargateLpStaking.eToken()));
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
        stargateLpStaking.deposit(tokenIdToPoolId[id], amount);
    }

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param id The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(uint256 id, uint256 amount) internal override {
        // Withdraw asset
        stargateLpStaking.withdraw(tokenIdToPoolId[id], amount);
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
        currentReward = stargateLpStaking.pendingEmissionToken(tokenIdToPoolId[id], address(this));
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
