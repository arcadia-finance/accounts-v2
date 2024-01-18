/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DerivedAssetModule, FixedPointMathLib, IRegistry } from "../AbstractDerivedAssetModule.sol";
import { IPool } from "./interfaces/IPool.sol";
import { ILpStakingTime } from "./interfaces/ILpStakingTime.sol";
import { StakingModule, ERC20 } from "../staking-module/AbstractStakingModule.sol";
import { AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";

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
    // The reward token (STG token)
    ERC20 public constant rewardToken = ERC20(0xE3B53AF74a4BF62Ae5511055290838050bf764Df);

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps a Stargate pool to its underlying asset.
    mapping(address asset => address underlyingAsset) public assetToUnderlyingAsset;
    // Maps a Stargate Pool to its specific pool id as referred to in the Stargate "lpStakingTime.sol" contract.
    mapping(address asset => uint256 poolId) public assetToPoolId;
    // Maps a Stargate Pool to its conversion rate, which is used in Stargate pools to convert from Local to Shared Decimals.
    mapping(address asset => uint256 conversionRate) public assetToConversionRate;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetAndRewardPairAlreadySet();
    error InvalidTokenDecimals();
    error PoolIdDoesNotMatch();
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
        StakingModule("ArcadiaStargatePositions", "ASP")
    {
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
     * @notice Adds a new Stargate Pool to the StargateAssetModule.
     * @param stargatePool The contract address of the Stargate LP Pool.
     * @param poolId The id of the stargatePool used in the lpStakingTime contract.
     */
    function addAsset(address stargatePool, uint256 poolId) external {
        if (ERC20(stargatePool).decimals() > 18) revert InvalidTokenDecimals();
        if (address(assetToRewardToken[stargatePool]) != address(0)) revert AssetAndRewardPairAlreadySet();

        (address pool,,,) = lpStakingTime.poolInfo(poolId);
        if (pool != stargatePool) revert PoolIdDoesNotMatch();

        address poolUnderlyingToken = IPool(stargatePool).token();

        if (!IRegistry(REGISTRY).isAllowed(poolUnderlyingToken, 0)) revert AssetNotAllowed();
        if (!IRegistry(REGISTRY).isAllowed(address(rewardToken), 0)) revert RewardTokenNotAllowed();

        assetToRewardToken[stargatePool] = rewardToken;
        assetToPoolId[stargatePool] = poolId;
        assetToUnderlyingAsset[stargatePool] = poolUnderlyingToken;
        assetToConversionRate[stargatePool] = IPool(stargatePool).convertRate();
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Checks for a token address and the corresponding id if it is allowed.
     * @param asset The contract address of the asset.
     * @return allowed A boolean, indicating if the asset is allowed.
     */
    function isAllowed(address asset, uint256) public view override returns (bool) {
        if (asset == address(this)) return true;
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
        address underlyingAsset = assetToUnderlyingAsset[positionState[positionId].asset];

        underlyingAssetKeys = new bytes32[](2);
        underlyingAssetKeys[0] = _getKeyFromAsset(underlyingAsset, 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(address(rewardToken), 0);
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param amount The amount of the Asset, in the decimal precision of the Asset.
     * @param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256 amount,
        bytes32[] memory underlyingAssetKeys
    )
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        // Amount of a Stargate position in the Asset Module can only be either 0 or 1.
        if (amount == 0) return (new uint256[](2), rateUnderlyingAssetsToUsd);

        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        (, uint256 positionId) = _getAssetFromKey(assetKey);
        PositionState storage positionState_ = positionState[positionId];

        // Cache Stargate pool address
        address asset = positionState_.asset;
        // Cache totalLiquidity
        uint256 totalLiquidity = IPool(asset).totalLiquidity();

        // Calculate underlyingAssets amounts.
        // "amountSD" is used in Stargate contracts and stands for amount in Shared Decimals, which should be converted to Local Decimals via convertRate().
        // "amountSD" will always be smaller or equal to amount in Local Decimals.
        // For an exisiting assetKey, the totalSupply can not be zero, as a non-zero amount is staked via this contract for the position.
        uint256 amountSD = uint256(positionState_.amountStaked).mulDivDown(totalLiquidity, IPool(asset).totalSupply());

        underlyingAssetsAmounts = new uint256[](2);
        underlyingAssetsAmounts[0] = amountSD * assetToConversionRate[asset];
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
        if (ERC20(asset).allowance(address(this), address(lpStakingTime)) < amount) {
            ERC20(asset).approve(address(lpStakingTime), type(uint256).max);
        }

        // Stake asset
        lpStakingTime.deposit(assetToPoolId[asset], amount);
    }

    /**
     * @notice Unstakes and withdraws the Asset from the external contract.
     * @param asset The contract address of the Asset to unstake and withdraw.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(address asset, uint256 amount) internal override {
        // Withdraw asset
        lpStakingTime.withdraw(assetToPoolId[asset], amount);
    }

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The contract address of the Asset to claim the rewards for.
     * @dev Withdrawing a zero amount will trigger the claim for rewards.
     */
    function _claimReward(address asset) internal override {
        lpStakingTime.withdraw(assetToPoolId[asset], 0);
    }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract for a specific asset.
     * @param asset The Asset to get the current rewards for.
     * @return currentReward The amount of reward tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view override returns (uint256 currentReward) {
        currentReward = lpStakingTime.pendingEmissionToken(assetToPoolId[asset], address(this));
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) { }
}
