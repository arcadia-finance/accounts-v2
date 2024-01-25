/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { DerivedAssetModule, FixedPointMathLib, IRegistry } from "../AbstractDerivedAssetModule.sol";
import { ERC20, StakingModule } from "../staking-module/AbstractStakingModule.sol";
import { ILpStakingTime } from "./interfaces/ILpStakingTime.sol";
import { IPool } from "./interfaces/IPool.sol";

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
    ILpStakingTime public immutable LP_STAKING_TIME;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps a Stargate Pool to its pool specific information.
    mapping(address asset => PoolInformation) public poolInformation;

    // Struct with additional information for a Stargate Pool.
    struct PoolInformation {
        // The contract of the underlying asset of the Stargate pool.
        address underlyingAsset;
        // The Stargate pool id in the "LP_STAKING_TIME.sol" contract.
        uint96 poolId;
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetAlreadySet();
    error BadPool();
    error RewardTokenNotAllowed();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param lpStakingTime_ The address of the Stargate LP staking contract.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC721 tokens is 1.
     */
    constructor(address registry_, address lpStakingTime_)
        DerivedAssetModule(registry_, 1)
        StakingModule("Arcadia Stargate Positions", "ASP")
    {
        LP_STAKING_TIME = ILpStakingTime(lpStakingTime_);
        REWARD_TOKEN = ERC20(address(LP_STAKING_TIME.eToken()));
        if (!IRegistry(REGISTRY).isAllowed(address(REWARD_TOKEN), 0)) revert RewardTokenNotAllowed();
    }

    /* //////////////////////////////////////////////////////////////
                               INITIALIZE
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice This function will add this contract as an asset in the Registry.
     * @dev Will revert if called more than once.
     */
    function initialize() external onlyOwner {
        inAssetModule[address(this)] = true;

        IRegistry(REGISTRY).addAsset(address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new Stargate Pool to the StargateAssetModule.
     * @param poolId The id of the stargatePool used in the LP_STAKING_TIME contract.
     */
    function addAsset(uint96 poolId) external {
        // poolInfo is an array -> will revert on a non-existing poolId.
        (address stargatePool,,,) = LP_STAKING_TIME.poolInfo(poolId);
        if (stargatePool == address(0)) revert BadPool();

        if (assetState[stargatePool].allowed) revert AssetAlreadySet();

        address underlyingAsset = IPool(stargatePool).token();
        if (!IRegistry(REGISTRY).isAllowed(underlyingAsset, 0)) revert AssetNotAllowed();

        _addAsset(stargatePool);
        poolInformation[stargatePool] = PoolInformation({ underlyingAsset: underlyingAsset, poolId: poolId });
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
        override
        returns (bytes32[] memory underlyingAssetKeys)
    {
        (, uint256 positionId) = _getAssetFromKey(assetKey);
        address pool = positionState[positionId].asset;

        underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = _getKeyFromAsset(poolInformation[pool].underlyingAsset, 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(address(REWARD_TOKEN), 0);
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
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        // Amount of a Stargate position in the Asset Module can only be either 0 or 1.
        if (amount == 0) return (new uint256[](2), rateUnderlyingAssetsToUsd);

        (, uint256 positionId) = _getAssetFromKey(assetKey);
        PositionState storage positionState_ = positionState[positionId];

        underlyingAssetsAmounts = new uint256[](2);
        // Calculate the amount of underlying tokens of the staked LP position.
        // "amountLPtoLD()" converts an amount of LP tokens into the corresponding amount of underlying tokens (LD stands for Local Decimals).
        // "amountLPtoLD()" reverts when totalSupply of the pool is zero,
        // but for an existing assetKey, the totalSupply cannot be zero, as only non-zero amounts can be staked via this contract.
        underlyingAssetsAmounts[0] = IPool(positionState_.asset).amountLPtoLD(positionState_.amountStaked);
        // Calculate the amount of reward tokens of the position.
        underlyingAssetsAmounts[1] = rewardOf(positionId);

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /*///////////////////////////////////////////////////////////////
                    INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens in the external staking contract.
     * @param asset The contract address of the Asset to stake.
     * @param amount The amount of Asset to stake.
     */
    function _stake(address asset, uint256 amount) internal override {
        ERC20(asset).approve(address(LP_STAKING_TIME), amount);

        // Stake asset
        LP_STAKING_TIME.deposit(poolInformation[asset].poolId, amount);
    }

    /**
     * @notice Unstakes and withdraws the Asset from the external contract.
     * @param asset The contract address of the Asset to unstake and withdraw.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(address asset, uint256 amount) internal override {
        // Withdraw asset
        LP_STAKING_TIME.withdraw(poolInformation[asset].poolId, amount);
    }

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The contract address of the Asset to claim the rewards for.
     * @dev Withdrawing a zero amount will trigger the claim for rewards.
     */
    function _claimReward(address asset) internal override {
        LP_STAKING_TIME.withdraw(poolInformation[asset].poolId, 0);
    }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract for a specific asset.
     * @param asset The Asset to get the current rewards for.
     * @return currentReward The amount of reward tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view override returns (uint256 currentReward) {
        currentReward = LP_STAKING_TIME.pendingEmissionToken(poolInformation[asset].poolId, address(this));
    }

    /*///////////////////////////////////////////////////////////////
                        ERC-721 LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc StakingModule
     */
    function setBaseURI(string calldata newBaseURI) external override onlyOwner {
        baseURI = newBaseURI;
    }
}
