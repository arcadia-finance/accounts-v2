/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StakingModule } from "../../../../src/asset-modules/staking-module/AbstractStakingModule.sol";
import { StakingModuleMock } from "../../../utils/mocks/StakingModuleMock.sol";
import { ERC20Mock } from "../../../utils/mocks/ERC20Mock.sol";

/**
 * @notice Common logic needed by "StakingModule" fuzz tests.
 */
abstract contract AbstractStakingModule_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct StakingModuleStateForAsset {
        uint128 currentRewardGlobal;
        uint128 lastRewardPerTokenGlobal;
        uint128 lastRewardGlobal;
        uint128 totalStaked;
    }

    struct StakingModuleStateForPosition {
        address asset;
        uint128 amountStaked;
        uint128 lastRewardPerTokenPosition;
        uint128 lastRewardPosition;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    StakingModuleMock internal stakingModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);

        stakingModule = new StakingModuleMock("StakingModuleTest", "SMT");

        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setStakingModuleState(
        StakingModuleStateForAsset memory stakingModuleStateForAsset,
        StakingModule.PositionState memory stakingModuleStateForPosition,
        address asset,
        uint256 id
    ) internal {
        stakingModule.setLastRewardGlobal(asset, stakingModuleStateForAsset.lastRewardGlobal);
        stakingModule.setTotalStaked(asset, stakingModuleStateForAsset.totalStaked);
        stakingModule.setLastRewardPosition(id, stakingModuleStateForPosition.lastRewardPosition);
        stakingModule.setLastRewardPerTokenPosition(id, stakingModuleStateForPosition.lastRewardPerTokenPosition);
        stakingModule.setLastRewardPerTokenGlobal(asset, stakingModuleStateForAsset.lastRewardPerTokenGlobal);
        stakingModule.setActualRewardBalance(asset, stakingModuleStateForAsset.currentRewardGlobal);
        stakingModule.setAmountStakedForPosition(id, stakingModuleStateForPosition.amountStaked);
        stakingModuleStateForPosition.asset = asset;
        stakingModule.setAssetInPosition(asset, id);
    }

    function givenValidStakingModuleState(
        StakingModuleStateForAsset memory stakingModuleStateForAsset,
        StakingModule.PositionState memory stakingModuleStateForPosition
    ) public view returns (StakingModuleStateForAsset memory, StakingModule.PositionState memory) {
        // Given: Current reward balance should be at least equal to lastRewardGlobal (invariant).
        stakingModuleStateForAsset.currentRewardGlobal = uint128(
            bound(
                stakingModuleStateForAsset.currentRewardGlobal,
                stakingModuleStateForAsset.lastRewardGlobal,
                type(uint128).max
            )
        );
        uint256 deltaReward =
            stakingModuleStateForAsset.currentRewardGlobal - stakingModuleStateForAsset.lastRewardGlobal;

        // And: deltaRewardPerToken is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        // -> totalStaked is bigger as deltaReward * 1e18 / type(uint128).max (rounded up).
        stakingModuleStateForAsset.totalStaked = uint128(
            bound(stakingModuleStateForAsset.totalStaked, 1 + deltaReward * 1e18 / type(uint128).max, type(uint128).max)
        );
        uint128 deltaRewardPerToken = uint128(deltaReward * 1e18 / stakingModuleStateForAsset.totalStaked);
        uint128 currentRewardPerTokenGlobal;
        unchecked {
            currentRewardPerTokenGlobal = stakingModuleStateForAsset.lastRewardPerTokenGlobal + deltaRewardPerToken;
        }

        // And: totalStaked should be >= to amountStakedForPosition (invariant).
        stakingModuleStateForPosition.amountStaked =
            uint128(bound(stakingModuleStateForPosition.amountStaked, 0, stakingModuleStateForAsset.totalStaked));

        // And: deltaReward of the position is smaller or equal to type(uint128).max (overflow).
        // -> deltaRewardPerToken * positionState_.amountStaked / 1e18 <= type(uint128).max;
        unchecked {
            deltaRewardPerToken = currentRewardPerTokenGlobal - stakingModuleStateForPosition.lastRewardPerTokenPosition;
        }
        if (stakingModuleStateForPosition.amountStaked > 0) {
            deltaRewardPerToken =
                uint128(bound(deltaRewardPerToken, 0, type(uint128).max / stakingModuleStateForPosition.amountStaked));
        }
        unchecked {
            stakingModuleStateForPosition.lastRewardPerTokenPosition = currentRewardPerTokenGlobal - deltaRewardPerToken;
        }
        deltaReward = deltaRewardPerToken * uint256(stakingModuleStateForPosition.amountStaked) / 1e18;

        // And: previously earned rewards for Account + new rewards should not be > type(uint128).max.
        stakingModuleStateForPosition.lastRewardPosition =
            uint128(bound(stakingModuleStateForPosition.lastRewardPosition, 0, type(uint128).max - deltaReward));

        return (stakingModuleStateForAsset, stakingModuleStateForPosition);
    }

    function addAssets(uint8 numberOfAssets, uint8 assetDecimals, uint8 rewardTokenDecimals)
        public
        returns (address[] memory assets, address[] memory rewardTokens)
    {
        assets = new address[](numberOfAssets);
        rewardTokens = new address[](numberOfAssets);

        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        for (uint8 i = 0; i < numberOfAssets; ++i) {
            ERC20Mock asset = new ERC20Mock("Asset", "AST", assetDecimals);
            ERC20Mock rewardToken = new ERC20Mock("RewardToken", "RWT", rewardTokenDecimals);

            assets[i] = address(asset);
            rewardTokens[i] = address(rewardToken);

            stakingModule.setAssetAndRewardToken(address(asset), rewardToken);
        }
    }
}
