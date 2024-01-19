/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DerivedAssetModule, FixedPointMathLib, IRegistry } from "../AbstractDerivedAssetModule.sol";
import { StakingModule, ERC20 } from "../staking-module/AbstractStakingModule.sol";
import { AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { IPool } from "./interfaces/IPool.sol";
import { IGauge } from "./interfaces/IGauge.sol";

/**
 * @title Asset-Module for Aerodrome Finance pools
 * @author Pragma Labs
 * @notice The AerodromeAssetModule stores pricing logic and basic information for Aerodrome Finance LP pools.
 * @dev No end-user should directly interact with the AerodromeAssetModule, only the Registry, the contract owner or via the actionHandler
 */
contract AerodromeAssetModule is DerivedAssetModule, StakingModule {
    using FixedPointMathLib for uint256;

    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The emission token (AERO token)
    ERC20 public constant rewardToken = ERC20(0x940181a94A35A4569E4529A3CDfB74e38FD98631);

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps a Stargate pool to its underlying asset.
    mapping(address asset => address[] underlyingAssets) public assetToUnderlyingAssets;
    mapping(address asset => address gauge) public assetToGauge;

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
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts for ERC721 tokens is 1.
     */
    constructor(address registry_)
        DerivedAssetModule(registry_, 1)
        StakingModule("Arcadia_Aerodrome_Positions", "AAP")
    { }

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
     * @notice Adds a new Aerodrome Pool to the AerodromeAssetModule.
     * @param pool The contract address of the Stargate LP Pool.
     * @param gauge The id of the stargatePool used in the lpStakingTime contract.
     */
    // note : check for malicious pool that could be done
    // note : Check for reward token (where are extra incentives claimable ?)
    function addAsset(address pool, address gauge) external onlyOwner {
        if (address(assetToRewardToken[pool]) != address(0)) revert AssetAndRewardPairAlreadySet();

        address token0 = IPool(pool).token0();
        address token1 = IPool(pool).token1();

        if (!IRegistry(REGISTRY).isAllowed(token0, 0)) revert AssetNotAllowed();
        if (!IRegistry(REGISTRY).isAllowed(token1, 0)) revert AssetNotAllowed();
        if (!IRegistry(REGISTRY).isAllowed(address(rewardToken), 0)) revert RewardTokenNotAllowed();

        address[] memory underlyingAssets = new address[](3);
        underlyingAssets[0] = token0;
        underlyingAssets[1] = token1;

        assetToUnderlyingAssets[pool] = underlyingAssets;
        assetToRewardToken[pool] = ERC20(rewardToken);
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
        // Cache Asset
        address asset = positionState[positionId].asset;

        underlyingAssetKeys = new bytes32[](3);
        underlyingAssetKeys[0] = _getKeyFromAsset(assetToUnderlyingAssets[asset][0], 0);
        underlyingAssetKeys[1] = _getKeyFromAsset(assetToUnderlyingAssets[asset][1], 0);
        underlyingAssetKeys[2] = _getKeyFromAsset(address(assetToRewardToken[asset]), 0);
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

        underlyingAssetsAmounts = new uint256[](3);
        underlyingAssetsAmounts[2] = rewardOf(positionId);

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
        address gauge = assetToGauge[asset];
        if (ERC20(asset).allowance(address(this), gauge) < amount) {
            ERC20(asset).approve(gauge, type(uint256).max);
        }

        // Stake asset
        IGauge(gauge).deposit(amount);
    }

    /**
     * @notice Unstakes and withdraws the Asset from the external contract.
     * @param asset The contract address of the Asset to unstake and withdraw.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(address asset, uint256 amount) internal override {
        // Withdraw asset
        IGauge(assetToGauge[asset]).withdraw(amount);
    }

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The contract address of the Asset to claim the rewards for.
     * @dev Withdrawing a zero amount will trigger the claim for rewards.
     */
    function _claimReward(address asset) internal override {
        //lpStakingTime.withdraw(assetToPoolId[asset], 0);
    }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract for a specific asset.
     * @param asset The Asset to get the current rewards for.
     * @return currentReward The amount of reward tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view override returns (uint256 currentReward) {
        //currentReward = lpStakingTime.pendingEmissionToken(assetToPoolId[asset], address(this));
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) { }
}
