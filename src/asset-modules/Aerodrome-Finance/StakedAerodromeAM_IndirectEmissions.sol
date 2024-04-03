/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20, IRegistry, StakingAM, FixedPointMathLib } from "../abstracts/AbstractStakingAM.sol";
import { IAeroGauge } from "./interfaces/IAeroGauge.sol";
import { IAeroVoter } from "./interfaces/IAeroVoter.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";

/**
 * @title Asset Module for Staked Aerodrome Finance pools
 * @author Pragma Labs
 * @notice The Staked Aerodrome Finance Asset Module stores pricing logic and basic information for Staked Aerodrome Finance LP pools.
 * This version of the Asset Module does not accrue rewards to the Account value. Rewards remain claimable by the owner of a position.
 * @dev No end-user should directly interact with the Staked Aerodrome Finance Asset Module, only the Registry, the contract owner or via the actionHandler
 */
contract StakedAerodromeAM_IndirectEmissions is StakingAM {
    using FixedPointMathLib for uint256;
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    IAeroVoter public immutable AERO_VOTER;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps an Aerodrome Finance Pool to its gauge.
    mapping(address asset => address gauge) public assetToGauge;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetAlreadySet();
    error PoolNotAllowed();
    error RewardTokenNotAllowed();
    error RewardTokenNotValid();
    error PoolOrGaugeNotValid();
    error GaugeNotValid();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry The address of the Registry.
     * @param aerodromeVoter The address of the Aerodrome Finance Voter contract.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "1" for ERC721 tokens.
     */
    constructor(address registry, address aerodromeVoter)
        StakingAM(registry, "Arcadia Aerodrome Positions", "aAEROP")
    {
        REWARD_TOKEN = ERC20(0x940181a94A35A4569E4529A3CDfB74e38FD98631);
        if (!IRegistry(REGISTRY).isAllowed(address(REWARD_TOKEN), 0)) revert RewardTokenNotAllowed();
        AERO_VOTER = IAeroVoter(aerodromeVoter);
    }

    /*///////////////////////////////////////////////////////////////
                            ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new Staked Aerodrome Finance pool to the StakedAerodromeAM.
     * @param pool The contract address of the Aerodrome Finance pool.
     * @param gauge The contract address of the gauge to stake the Aerodrome Finance LP.
     */
    function addAsset(address pool, address gauge) external {
        if (!IRegistry(REGISTRY).isAllowed(pool, 0)) revert PoolNotAllowed();
        if (assetState[pool].allowed) revert AssetAlreadySet();

        if (AERO_VOTER.isGauge(gauge) != true) revert GaugeNotValid();
        if (IAeroGauge(gauge).stakingToken() != pool) revert PoolOrGaugeNotValid();
        if (IAeroGauge(gauge).rewardToken() != address(REWARD_TOKEN)) revert RewardTokenNotValid();

        assetToGauge[pool] = gauge;
        _addAsset(pool);
    }

    /*///////////////////////////////////////////////////////////////
                            ASSET INFORMATION
    ///////////////////////////////////////////////////////////////*/

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

        underlyingAssetKeys = new bytes32[](1);
        underlyingAssetKeys[0] = _getKeyFromAsset(positionState[positionId].asset, 0);
    }

    /**
     * @notice Calculates for a given amount of Asset the corresponding amount of underlying asset.
     * param creditor The contract address of the creditor.
     * @param assetKey The unique identifier of the asset.
     * @param amount The amount of the Asset, in the decimal precision of the Asset.
     * param underlyingAssetKeys The unique identifiers of the underlying assets.
     * @return underlyingAssetsAmounts The corresponding amount of Underlying Asset, in the decimal precision of the Underlying Asset.
     * @return rateUnderlyingAssetsToUsd The usd rates of 10**18 tokens of underlying asset, with 18 decimals precision.
     */
    function _getUnderlyingAssetsAmounts(address, bytes32 assetKey, uint256 amount, bytes32[] memory)
        internal
        view
        override
        returns (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd)
    {
        // Amount of a Staked position in the Asset Module can only be either 0 or 1.
        if (amount == 0) return (new uint256[](1), rateUnderlyingAssetsToUsd);

        (, uint256 positionId) = _getAssetFromKey(assetKey);

        underlyingAssetsAmounts = new uint256[](1);
        underlyingAssetsAmounts[0] = positionState[positionId].amountStaked;

        return (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd);
    }

    /*///////////////////////////////////////////////////////////////
                            PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the USD value of an asset.
     * @param creditor The contract address of the Creditor.
     * @param underlyingAssetsAmounts The corresponding amount of Underlying Asset, in the decimal precision of the Underlying Asset.
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
    ) internal view override returns (uint256 valueInUsd, uint256 collateralFactor, uint256 liquidationFactor) {
        // "rateUnderlyingAssetsToUsd" is the USD value with 18 decimals precision for 10**18 tokens of Underlying Asset.
        // To get the USD value (also with 18 decimals) of the actual amount of underlying assets, we have to multiply
        // the actual amount with the rate for 10**18 tokens, and divide by 10**18.
        valueInUsd = underlyingAssetsAmounts[0].mulDivDown(rateUnderlyingAssetsToUsd[0].assetValue, 1e18);

        // Lower risk factors with the protocol wide risk factor.
        uint256 riskFactor = riskParams[creditor].riskFactor;
        collateralFactor = riskFactor.mulDivDown(rateUnderlyingAssetsToUsd[0].collateralFactor, AssetValuationLib.ONE_4);
        liquidationFactor =
            riskFactor.mulDivDown(rateUnderlyingAssetsToUsd[0].liquidationFactor, AssetValuationLib.ONE_4);
    }

    /*///////////////////////////////////////////////////////////////
                     INTERACTIONS STAKING CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Stakes an amount of tokens in the external staking contract.
     * @param asset The contract address of the Asset to stake.
     * @param amount The amount of Asset to stake.
     */
    function _stakeAndClaim(address asset, uint256 amount) internal override {
        address gauge = assetToGauge[asset];

        // Claim rewards
        IAeroGauge(gauge).getReward(address(this));

        // Stake asset
        ERC20(asset).approve(gauge, amount);
        IAeroGauge(gauge).deposit(amount);
    }

    /**
     * @notice Unstakes and withdraws the Asset from the external contract.
     * @param asset The contract address of the Asset to unstake and withdraw.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdrawAndClaim(address asset, uint256 amount) internal override {
        address gauge = assetToGauge[asset];

        // Claim rewards
        IAeroGauge(gauge).getReward(address(this));

        // Withdraw asset
        IAeroGauge(gauge).withdraw(amount);
    }

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The contract address of the Asset to claim the rewards for.
     * @dev Withdrawing a zero amount will trigger the claim for rewards.
     */
    function _claimReward(address asset) internal override {
        IAeroGauge(assetToGauge[asset]).getReward(address(this));
    }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract for a specific asset.
     * @param asset The Asset to get the current rewards for.
     * @return currentReward The amount of reward tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view override returns (uint256 currentReward) {
        currentReward = IAeroGauge(assetToGauge[asset]).earned(address(this));
    }
}
