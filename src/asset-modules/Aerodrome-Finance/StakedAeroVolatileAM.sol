/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20, IRegistry, StakingAM } from "../abstracts/AbstractStakingAM.sol";
import { ILpStakingTime } from "./interfaces/ILpStakingTime.sol";

/**
 * @title Asset Module for Staked Stargate Finance pools
 * @author Pragma Labs
 * @notice The Staked Stargate Asset Module stores pricing logic and basic information for Staked Stargate Finance LP pools
 * @dev No end-user should directly interact with the Staked Stargate Asset Module, only the Registry, the contract owner or via the actionHandler
 */
contract StakedStargateAM is StakingAM {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Maps an Aerodrome Pool to its gauge.
    mapping(address asset => address gauge) public assetToGauge;

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    error AssetAlreadySet();
    error PoolNotAllowed();
    error RewardTokenNotAllowed();

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry The address of the Registry.
     * @dev The ASSET_TYPE, necessary for the deposit and withdraw logic in the Accounts, is "1" for ERC721 tokens.
     */
    constructor(address registry) StakingAM(registry, "Arcadia Aerodrome Positions", "aAEROP") {
        REWARD_TOKEN = ERC20(0x940181a94A35A4569E4529A3CDfB74e38FD98631);
        if (!IRegistry(REGISTRY).isAllowed(address(REWARD_TOKEN), 0)) revert RewardTokenNotAllowed();
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new Staked Stargate Pool to the StargateAssetModule.
     * @param pid The id of the stargatePool used in the LP_STAKING_TIME contract.
     */
    function addAsset(address pool, address gauge) external {
        if (!IRegistry(REGISTRY).isAllowed(pool, 0)) revert PoolNotAllowed();
        if (assetToGauge[pool] != address(0)) revert AssetAlreadyAdded();
        if (IGauge(gauge).stakingToken() != pool) revert PoolOrGaugeNotValid();
        if (IGauge(gauge).rewardToken() != address(REWARD_TOKEN)) revert RewardTokenNotValid();

        assetToGauge[pool] = gauge;

        bytes32[] memory underlyingAssetsKey = new bytes32[](3);
        underlyingAssetsKey[0] = _getKeyFromAsset(token0, 0);
        underlyingAssetsKey[1] = _getKeyFromAsset(token1, 0);
        underlyingAssetsKey[2] = _getKeyFromAsset(rewardToken_, 0);

        assetToUnderlyingAssets[_getKeyFromAsset(pool, 0)] = underlyingAssetsKey;
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
        LP_STAKING_TIME.deposit(assetToPid[asset], amount);
    }

    /**
     * @notice Unstakes and withdraws the Asset from the external contract.
     * @param asset The contract address of the Asset to unstake and withdraw.
     * @param amount The amount of underlying tokens to unstake and withdraw.
     */
    function _withdraw(address asset, uint256 amount) internal override {
        // Withdraw asset
        LP_STAKING_TIME.withdraw(assetToPid[asset], amount);
    }

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The contract address of the Asset to claim the rewards for.
     * @dev Withdrawing a zero amount will trigger the claim for rewards.
     */
    function _claimReward(address asset) internal override {
        LP_STAKING_TIME.withdraw(assetToPid[asset], 0);
    }

    /**
     * @notice Returns the amount of reward tokens that can be claimed by this contract for a specific asset.
     * @param asset The Asset to get the current rewards for.
     * @return currentReward The amount of reward tokens that can be claimed.
     */
    function _getCurrentReward(address asset) internal view override returns (uint256 currentReward) {
        currentReward = LP_STAKING_TIME.pendingEmissionToken(assetToPid[asset], address(this));
    }
}
