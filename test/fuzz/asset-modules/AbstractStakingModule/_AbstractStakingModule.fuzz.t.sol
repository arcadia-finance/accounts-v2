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
        // Given: More than 1 gwei is staked.
        stakingModuleStateForAsset.totalStaked =
            uint128(bound(stakingModuleStateForAsset.totalStaked, 1, type(uint128).max));

        // And: totalStaked should be >= to amountStakedForPosition (invariant).
        stakingModuleStateForPosition.amountStaked =
            uint128(bound(stakingModuleStateForPosition.amountStaked, 0, stakingModuleStateForAsset.totalStaked));

        // And: deltaRewardPerToken is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        uint256 deltaReward;
        unchecked {
            deltaReward = stakingModuleStateForAsset.currentRewardGlobal - stakingModuleStateForAsset.lastRewardGlobal;
        }
        deltaReward = bound(deltaReward, 1, uint256(type(uint128).max) * stakingModuleStateForAsset.totalStaked / 1e18);

        // And: currentRewardGlobal is smaller or equal than type(uint128).max (no overflow safeCastTo128).
        stakingModuleStateForAsset.currentRewardGlobal =
            uint128(bound(stakingModuleStateForAsset.currentRewardGlobal, deltaReward, type(uint128).max));
        stakingModuleStateForAsset.lastRewardGlobal =
            uint128(stakingModuleStateForAsset.currentRewardGlobal - deltaReward);

        // Calculate the new rewardPerTokenGlobal.
        uint256 deltaRewardPerToken = deltaReward * 1e18 / stakingModuleStateForAsset.totalStaked;
        uint128 currentRewardPerTokenGlobal;
        unchecked {
            currentRewardPerTokenGlobal =
                stakingModuleStateForAsset.lastRewardPerTokenGlobal + uint128(deltaRewardPerToken);
        }

        // And: Previously earned rewards for Account + new rewards does not overflow.
        // -> deltaReward of the position is smaller or equal to type(uint128).max (overflow).
        // -> deltaRewardPerToken * positionState_.amountStaked / 1e18 <= type(uint128).max;
        unchecked {
            deltaRewardPerToken = currentRewardPerTokenGlobal - stakingModuleStateForPosition.lastRewardPerTokenPosition;
        }
        if (stakingModuleStateForPosition.amountStaked > 0) {
            deltaRewardPerToken = uint128(
                bound(
                    deltaRewardPerToken,
                    0,
                    type(uint128).max * uint256(1e18) / stakingModuleStateForPosition.amountStaked
                )
            );
        }
        unchecked {
            stakingModuleStateForPosition.lastRewardPerTokenPosition =
                currentRewardPerTokenGlobal - uint128(deltaRewardPerToken);
        }
        deltaReward = deltaRewardPerToken * uint256(stakingModuleStateForPosition.amountStaked) / 1e18;

        // And: Previously earned rewards for Account + new rewards does not overflow.
        // -> lastRewardPosition + deltaReward <= type(uint128).max;
        stakingModuleStateForPosition.lastRewardPosition =
            uint128(bound(stakingModuleStateForPosition.lastRewardPosition, 0, type(uint128).max - deltaReward));

        return (stakingModuleStateForAsset, stakingModuleStateForPosition);
    }

    function addAssets(uint8 assetDecimals, uint8 rewardTokenDecimals)
        public
        returns (address asset_, address rewardToken)
    {
        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        rewardTokenDecimals = uint8(bound(rewardTokenDecimals, 0, 18));

        asset_ = address(new ERC20Mock("Asset", "AST", assetDecimals));
        rewardToken = address(new ERC20Mock("RewardToken", "RWT", rewardTokenDecimals));

        stakingModule.setAssetAndRewardToken(asset_, ERC20Mock(rewardToken));
    }
}
