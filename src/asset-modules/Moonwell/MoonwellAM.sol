/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AssetValuationLib, AssetValueAndRiskFactors } from "../../libraries/AssetValuationLib.sol";
import { IComptroller } from "./interfaces/IComptroller.sol";
import { IMoonwellViews, Rewards } from "./interfaces/IMoonwellViews.sol";
import { WrappedAM } from "../abstracts/AbstractWrappedAM.sol";

/**
 * @title Asset Module for non-staked Stargate Finance pools
 * @author Pragma Labs
 * @notice The Stargate Asset Module stores pricing logic and basic information for Stargate Finance LP pools
 * @dev No end-user should directly interact with the Stargate Asset Module, only the Registry, the contract owner or via the actionHandler
 */
contract MoonwellAM is WrappedAM {
    /* //////////////////////////////////////////////////////////////
                                CONSTANTS
    ////////////////////////////////////////////////////////////// */

    IMoonwellViews internal immutable MOONWELL_VIEWS;
    IComptroller internal immutable COMPTROLLER;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param registry_ The address of the Registry.
     * @param name_ Name of the Wrapper Module.
     * @param symbol_ Symbol of the Wrapper Module.
     * @param moonwellViews The Moonwell view contract.
     */
    constructor(
        address registry_,
        string memory name_,
        string memory symbol_,
        address moonwellViews,
        address comptroller
    ) WrappedAM(registry_, name_, symbol_) {
        MOONWELL_VIEWS = IMoonwellViews(moonwellViews);
        COMPTROLLER = IComptroller(comptroller);
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new asset to this contract. An asset represents the combination of a mToken and associated rewards, see customAsset below.
     * @param mToken The mToken to add to the Asset-Module.
     * @param rewards_ An array with all reward addresses for a specific mToken that will be accounted as collateral in the Account.
     * @return customAsset The combination of the mToken and rewards_ that are hashed together and converted to an address.
     */
    function addAsset(address mToken, address[] memory rewards_) external returns (address customAsset) {
        customAsset = _addAsset(mToken, rewards_);
    }

    /*///////////////////////////////////////////////////////////////
                    INTERACTIONS REWARD CONTRACT
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Claims the rewards available for this contract.
     * @param asset The Asset for which rewards will be claimed.
     * param rewards The active rewards in this contract to claim.
     */
    function _claimRewards(address asset, address[] memory) internal override {
        address[] memory holder = new address[](1);
        holder[0] = address(this);
        address[] memory mToken = new address[](1);
        mToken[0] = asset;

        COMPTROLLER.claimReward(holder, mToken, false, true);
    }

    /**
     * @notice Returns the amount of reward tokens that can be claimed for a specific Asset by this contract.
     * @param asset The Asset that is earning rewards.
     * @param rewards The reward earned by the Asset.
     * @return currentRewards The amount of rewards tokens that can be claimed.
     */
    function _getCurrentRewards(address asset, address[] memory rewards)
        internal
        view
        override
        returns (uint256[] memory currentRewards)
    {
        currentRewards = new uint256[](rewards.length);
        Rewards[] memory rewardsEarned = MOONWELL_VIEWS.getUserRewards(address(this));

        address[] memory matchingRewardTokens = new address[](MAX_REWARDS);
        uint256[] memory structArrayIds = new uint256[](MAX_REWARDS);

        uint256 matches;
        for (uint256 i; i < rewardsEarned.length; ++i) {
            if (rewardsEarned[i].market == asset) {
                if (matches == MAX_REWARDS) break;
                matchingRewardTokens[matches] = rewardsEarned[i].rewardToken;
                structArrayIds[matches] = i;
                ++matches;
            }
        }

        for (uint256 i = 0; i < rewards.length; ++i) {
            for (uint256 j = 0; j < matches; ++j) {
                if (rewards[i] == matchingRewardTokens[j]) {
                    currentRewards[i] = rewardsEarned[structArrayIds[j]].supplyRewardsAmount;
                    break;
                }
            }
        }
    }
}
