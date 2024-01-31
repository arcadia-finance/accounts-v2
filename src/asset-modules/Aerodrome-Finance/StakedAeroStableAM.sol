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

    // Maps an Aerodrome pool to its underlying assets.
    mapping(bytes32 asset => bytes32[] underlyingAssets) public assetToUnderlyingAssets;
    mapping(address asset => address gauge) public assetToGauge;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetAlreadyAdded();
    error InvalidTokenDecimals();
    error PoolIdDoesNotMatch();
    error RewardTokenNotAllowed();
    error PoolOrGaugeNotValid();
    error ZeroReserves();

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
    // note : Check if onlyOwner needed
    function addAsset(address pool, address gauge) external onlyOwner {
        if (assetToGauge[pool] != address(0)) revert AssetAlreadyAdded();
        if (IGauge(gauge).stakingToken() != pool) revert PoolOrGaugeNotValid();

        (address token0, address token1) = IPool(pool).tokens();

        if (!IRegistry(REGISTRY).isAllowed(token0, 0)) revert AssetNotAllowed();
        if (!IRegistry(REGISTRY).isAllowed(token1, 0)) revert AssetNotAllowed();

        // Cache rewardToken
        address rewardToken_ = address(rewardToken);
        if (!IRegistry(REGISTRY).isAllowed(rewardToken_, 0)) revert RewardTokenNotAllowed();

        assetToRewardToken[pool] = rewardToken;
        assetToGauge[pool] = gauge;

        bytes32[] memory underlyingAssetsKey = new bytes32[](3);
        underlyingAssetsKey[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetsKey[1] = _getKeyFromAsset(token1, 0);
        underlyingAssetsKey[2] = _getKeyFromAsset(rewardToken_, 0);

        assetToUnderlyingAssets[_getKeyFromAsset(pool, 0)] = underlyingAssetsKey;
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
        bytes32 positionAssetKey = _getKeyFromAsset(positionState[positionId].asset, 0);
        underlyingAssetKeys = assetToUnderlyingAssets[positionAssetKey];
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
        // Amount of an Aerodrome position in the Asset Module can only be either 0 or 1.
        if (amount == 0) return (new uint256[](3), rateUnderlyingAssetsToUsd);

        rateUnderlyingAssetsToUsd = _getRateUnderlyingAssetsToUsd(creditor, underlyingAssetKeys);
        (, uint256 positionId) = _getAssetFromKey(assetKey);

        // Cache asset and staked balance
        address asset = positionState[positionId].asset;

        underlyingAssetsAmounts = new uint256[](3);
        (underlyingAssetsAmounts[0], underlyingAssetsAmounts[1]) = _getTrustedTokenAmounts(
            asset, rateUnderlyingAssetsToUsd[0].assetValue, rateUnderlyingAssetsToUsd[1].assetValue, assetAmount
        );
        /* 
        // The untrusted reserves from the pair, these can be manipulated!!!
        (uint256 reserve0, uint256 reserve1,) = IPool(asset).getReserves();

        // Note : not sure it makes sense since position has a positive amount staked (if kept add testing)
        if (reserve0 == 0 || reserve1 == 0) revert ZeroReserves();

        // Cache totalSupply and amountStaked
        uint256 totalSupply = IPool(asset).totalSupply();
        uint256 amountStaked = positionState[positionId].amountStaked;

        underlyingAssetsAmounts = new uint256[](3);
        underlyingAssetsAmounts[0] = reserve0.mulDivDown(amountStaked, totalSupply);
        underlyingAssetsAmounts[1] = reserve1.mulDivDown(amountStaked, totalSupply);
        underlyingAssetsAmounts[2] = rewardOf(positionId); */

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /**
     * @notice Returns the trusted amount of token0 provided as liquidity, given two trusted prices of token0 and token1
     * @param pair Address of the Uniswap V2 Liquidity pool
     * @param trustedPriceToken0 Trusted price of an amount of Token0 in a given Numeraire
     * @param trustedPriceToken1 Trusted price of an amount of Token1 in a given Numeraire
     * @param liquidityAmount The amount of LP tokens (ERC20)
     * @return token0Amount The trusted amount of token0 provided as liquidity
     * @return token1Amount The trusted amount of token1 provided as liquidity
     * @dev Both trusted prices must be for the same Numeraire, and for an equal amount of tokens
     *      e.g. if trustedPriceToken0 is the USD price for 10**18 tokens of token0,
     *      than trustedPriceToken2 must be the USD price for 10**18 tokens of token1.
     *      The amount of tokens should be big enough to guarantee enough precision for tokens with small unit-prices
     * @dev The trusted amount of liquidity is calculated by first bringing the liquidity pool in equilibrium,
     *      by calculating what the reserves of the pool would be if a profit-maximizing trade is done.
     *      As such flash-loan attacks are mitigated, where an attacker swaps a large amount of the higher priced token,
     *      to bring the pool out of equilibrium, resulting in liquidity positions with a higher share of the most valuable token.
     * @dev Modification of https://github.com/Uniswap/v2-periphery/blob/master/contracts/libraries/UniswapV2LiquidityMathLibrary.sol#L23
     */
    function _getTrustedTokenAmounts(
        address pair,
        uint256 trustedPriceToken0,
        uint256 trustedPriceToken1,
        uint256 liquidityAmount
    ) internal view returns (uint256 token0Amount, uint256 token1Amount) {
        uint256 kLast = feeOn ? IUniswapV2Pair(pair).kLast() : 0;
        uint256 totalSupply = IUniswapV2Pair(pair).totalSupply();

        // this also checks that totalSupply > 0
        if (totalSupply == 0) revert Zero_Supply();

        (uint256 reserve0, uint256 reserve1) = _getTrustedReserves(pair, trustedPriceToken0, trustedPriceToken1);

        return _computeTokenAmounts(reserve0, reserve1, totalSupply, liquidityAmount, kLast);
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
        IGauge(assetToGauge[asset]).getReward(address(this));
    }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract for a specific asset.
     * @param asset The Asset to get the current rewards for.
     * @return currentReward The amount of reward tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view override returns (uint256 currentReward) {
        currentReward = IGauge(assetToGauge[asset]).earned(address(this));
    }

    function tokenURI(uint256 id) public view virtual override returns (string memory) { }
}
