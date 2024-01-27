/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Test, Constants } from "../../Fuzz.t.sol";

import { StakingAM } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";
import { StakingAMMock } from "../../../utils/mocks/asset-modules/StakingAMMock.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";

/**
 * @notice Common logic needed by "StakingAM" fuzz tests.
 */
abstract contract AbstractStakingAM_Fuzz_Test is Fuzz_Test {
    /*////////////////////////////////////////////////////////////////
                            VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct StakingAMStateForAsset {
        uint128 currentRewardGlobal;
        uint128 lastRewardPerTokenGlobal;
        uint128 lastRewardGlobal;
        uint128 totalStaked;
    }

    struct StakingAMStateForPosition {
        address asset;
        uint128 amountStaked;
        uint128 lastRewardPerTokenPosition;
        uint128 lastRewardPosition;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ERC20Mock internal rewardToken;
    StakingAMMock internal stakingAM;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test) {
        Fuzz_Test.setUp();

        vm.startPrank(users.creatorAddress);
        rewardToken = new ERC20Mock("RewardToken", "RWT", 18);
        stakingAM = new StakingAMMock(address(registryExtension), "StakingAMTest", "SMT", address(rewardToken));
        vm.stopPrank();
    }

    /* ///////////////////////////////////////////////////////////////
                          HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function setStakingAMState(
        StakingAMStateForAsset memory stakingAMStateForAsset,
        StakingAM.PositionState memory stakingAMStateForPosition,
        address asset,
        uint96 id
    ) internal {
        stakingAM.setLastRewardGlobal(asset, stakingAMStateForAsset.lastRewardGlobal);
        stakingAM.setTotalStaked(asset, stakingAMStateForAsset.totalStaked);
        stakingAM.setLastRewardPosition(id, stakingAMStateForPosition.lastRewardPosition);
        stakingAM.setLastRewardPerTokenPosition(id, stakingAMStateForPosition.lastRewardPerTokenPosition);
        stakingAM.setLastRewardPerTokenGlobal(asset, stakingAMStateForAsset.lastRewardPerTokenGlobal);
        stakingAM.setActualRewardBalance(asset, stakingAMStateForAsset.currentRewardGlobal);
        stakingAM.setAmountStakedForPosition(id, stakingAMStateForPosition.amountStaked);
        stakingAMStateForPosition.asset = asset;
        stakingAM.setAssetInPosition(asset, id);
    }

    function givenValidStakingAMState(
        StakingAMStateForAsset memory stakingAMStateForAsset,
        StakingAM.PositionState memory stakingAMStateForPosition
    ) public view returns (StakingAMStateForAsset memory, StakingAM.PositionState memory) {
        // Given: More than 1 gwei is staked.
        stakingAMStateForAsset.totalStaked = uint128(bound(stakingAMStateForAsset.totalStaked, 1, type(uint128).max));

        // And: totalStaked should be >= to amountStakedForPosition (invariant).
        stakingAMStateForPosition.amountStaked =
            uint128(bound(stakingAMStateForPosition.amountStaked, 0, stakingAMStateForAsset.totalStaked));

        // And: deltaRewardPerToken is smaller or equal as type(uint128).max (no overflow safeCastTo128).
        uint256 deltaReward;
        unchecked {
            deltaReward = stakingAMStateForAsset.currentRewardGlobal - stakingAMStateForAsset.lastRewardGlobal;
        }
        deltaReward = bound(deltaReward, 1, uint256(type(uint128).max) * stakingAMStateForAsset.totalStaked / 1e18);

        // And: currentRewardGlobal is smaller or equal than type(uint128).max (no overflow safeCastTo128).
        stakingAMStateForAsset.currentRewardGlobal =
            uint128(bound(stakingAMStateForAsset.currentRewardGlobal, deltaReward, type(uint128).max));
        stakingAMStateForAsset.lastRewardGlobal = uint128(stakingAMStateForAsset.currentRewardGlobal - deltaReward);

        // Calculate the new rewardPerTokenGlobal.
        uint256 deltaRewardPerToken = deltaReward * 1e18 / stakingAMStateForAsset.totalStaked;
        uint128 currentRewardPerTokenGlobal;
        unchecked {
            currentRewardPerTokenGlobal = stakingAMStateForAsset.lastRewardPerTokenGlobal + uint128(deltaRewardPerToken);
        }

        // And: Previously earned rewards for Account + new rewards does not overflow.
        // -> deltaReward of the position is smaller or equal to type(uint128).max (overflow).
        // -> deltaRewardPerToken * positionState_.amountStaked / 1e18 <= type(uint128).max;
        unchecked {
            deltaRewardPerToken = currentRewardPerTokenGlobal - stakingAMStateForPosition.lastRewardPerTokenPosition;
        }
        if (stakingAMStateForPosition.amountStaked > 0) {
            deltaRewardPerToken = uint128(
                bound(
                    deltaRewardPerToken, 0, type(uint128).max * uint256(1e18) / stakingAMStateForPosition.amountStaked
                )
            );
        }
        unchecked {
            stakingAMStateForPosition.lastRewardPerTokenPosition =
                currentRewardPerTokenGlobal - uint128(deltaRewardPerToken);
        }
        deltaReward = deltaRewardPerToken * uint256(stakingAMStateForPosition.amountStaked) / 1e18;

        // And: Previously earned rewards for Account + new rewards does not overflow.
        // -> lastRewardPosition + deltaReward <= type(uint128).max;
        stakingAMStateForPosition.lastRewardPosition =
            uint128(bound(stakingAMStateForPosition.lastRewardPosition, 0, type(uint128).max - deltaReward));

        return (stakingAMStateForAsset, stakingAMStateForPosition);
    }

    function addAsset(uint8 assetDecimals) public returns (address asset_) {
        assetDecimals = uint8(bound(assetDecimals, 0, 18));
        asset_ = address(new ERC20Mock("Asset", "AST", assetDecimals));
        stakingAM.addAsset(asset_);
    }
}
