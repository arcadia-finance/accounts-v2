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

    // The reward token (STG token)
    ERC20 public constant rewardToken_ = ERC20(0xE3B53AF74a4BF62Ae5511055290838050bf764Df);

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps this contract's ERC1155 assetKeys to the keys of their underlying asset.
    mapping(address asset => address underlyingAsset) public assetToUnderlyingAsset;
    // The pool id as referred to in the Stargate "lpStakingTime.sol" contract relative to the underlying asset of the ERC1155 token id.
    mapping(address asset => uint256 poolId) public assetToPoolId;
    // Maps a token id to a boolean indicating if the token id is allowed.
    mapping(uint256 id => bool allowed) public allowedTokenId;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error RewardsOnlyClaimableOnWithdrawal();
    error AssetAndRewardPairAlreadySet();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param lpStakingTime_ The address of the Stargate LP staking contract.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC1155 tokens is 2.
     */
    constructor(address registry_, address lpStakingTime_)
        DerivedAssetModule(registry_, 2)
        StakingModule("ArcadiaStargatePositions", "ASP")
    {
        lpStakingTime = ILpStakingTime(lpStakingTime_);
    }

    /*///////////////////////////////////////////////////////////////
                        STAKING TOKEN MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset (ERC1155 tokenId and it's corresponding Stargate Pool LP) to the StargateAssetModule.
     * @param stargatePool The ERC1155 token id of this contract.
     * @param poolId x
     */
    // Note : discuss if this should be an onlyOwner fct
    // Note : can we do a check on assetToPoolId
    function addStakingToken(address stargatePool, uint256 poolId) external onlyOwner {
        if (ERC20(stargatePool).decimals() > 18) revert InvalidTokenDecimals();

        if (address(assetToRewardToken[stargatePool]) != address(0)) revert AssetAndRewardPairAlreadySet();

        address poolUnderlyingToken = IPool(stargatePool).token();

        if (!IRegistry(REGISTRY).isAllowed(poolUnderlyingToken, 0)) revert AssetNotAllowed();

        assetToRewardToken[stargatePool] = rewardToken_;
        assetToPoolId[stargatePool] = poolId;
        assetToUnderlyingAsset[stargatePool] = poolUnderlyingToken;
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
        (, uint256 tokenId) = _getAssetFromKey(assetKey);
        address underlyingAsset = assetToUnderlyingAsset[positionState[tokenId].asset];

        underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] = _getKeyFromAsset(underlyingAsset, 0);
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount(s) of underlying asset(s).
     * @param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * param assetAmount The amount of the asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount(s) of Underlying Asset(s), in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(
        address creditor,
        bytes32 assetKey,
        uint256,
        bytes32[] memory underlyingAssetKeys
    )
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);

        (, uint256 tokenId) = _getAssetFromKey(assetKey);

        PositionState storage positionState_ = positionState[tokenId];

        underlyingAssetsAmounts = new uint256[](1);

        // Cache Stargate pool address
        address asset = positionState_.asset;
        // Cache totalLiquidity
        uint256 totalLiquidity = IPool(asset).totalLiquidity();

        // Calculate underlyingAssets amounts.
        // "amountSD" is used in Stargate contracts and stands for amount in Shared Decimals, which should be convered to Local Decimals via convertRate().
        // "amountSD" will always be smaller or equal to amount in Local Decimals.
        uint256 amountSD = totalLiquidity != 0
            ? uint256(positionState_.amountStaked).mulDivDown(totalLiquidity, IPool(asset).totalSupply())
            : 0;

        underlyingAssetsAmounts[0] = amountSD * IPool(asset).convertRate();

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
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
     * @param asset The id of the specific staking token.
     * @param amount The amount of underlying tokens to stake.
     */
    function _stake(address asset, uint256 amount) internal override {
        if (ERC20(asset).allowance(address(this), address(lpStakingTime)) < amount) {
            ERC20(asset).approve(address(lpStakingTime), type(uint256).max);
        }

        // Stake asset
        lpStakingTime.deposit(assetToPoolId[asset], amount);
    }

    /**
     * @notice Unstakes and withdraws the staking token from the external contract.
     * @param asset The id of the specific staking token.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(address asset, uint256 amount) internal override {
        // Withdraw asset
        lpStakingTime.withdraw(assetToPoolId[asset], amount);
    }

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The id of the specific staking token.
     * @dev This function is left empty as there is no method on Stargate contract to claim rewards separately. Accounts have to withdraw in order to claim rewards.
     */
    function _claimReward(address asset) internal override { }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract for a specific asset.
     * @param asset The id of the specific staking token.
     * @return currentReward The amount of rewards tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view override returns (uint256 currentReward) {
        currentReward = lpStakingTime.pendingEmissionToken(assetToPoolId[asset], address(this));
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) { }
}
