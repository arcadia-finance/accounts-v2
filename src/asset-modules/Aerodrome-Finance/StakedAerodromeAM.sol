/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20, IRegistry, StakingAM } from "../abstracts/AbstractStakingAM.sol";
import { IAeroGauge } from "./interfaces/IAeroGauge.sol";
import { IAeroVoter } from "./interfaces/IAeroVoter.sol";

/**
 * @title Asset Module for Staked Aerodrome Finance pools
 * @author Pragma Labs
 * @notice The Staked Aerodrome Finance Asset Module stores pricing logic
 * and basic information for Staked Aerodrome Finance LP pools.
 */
contract StakedAerodromeAM is StakingAM {
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
    error GaugeNotValid();
    error PoolNotAllowed();
    error RewardTokenNotAllowed();
    error RewardTokenNotValid();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry The address of the Registry.
     * @param aerodromeVoter The address of the Aerodrome Finance Voter contract.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "2" for ERC721 tokens.
     */
    constructor(address registry, address aerodromeVoter)
        StakingAM(registry, "Arcadia Staked Aerodrome Positions", "aSAEROP")
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
     * @param gauge The contract address of the gauge to stake the Aerodrome Finance LP.
     */
    function addAsset(address gauge) external {
        if (AERO_VOTER.isGauge(gauge) != true) revert GaugeNotValid();

        address pool = IAeroGauge(gauge).stakingToken();
        if (!IRegistry(REGISTRY).isAllowed(pool, 0)) revert PoolNotAllowed();
        if (assetState[pool].allowed) revert AssetAlreadySet();

        if (IAeroGauge(gauge).rewardToken() != address(REWARD_TOKEN)) revert RewardTokenNotValid();

        assetToGauge[pool] = gauge;
        _addAsset(pool);
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
