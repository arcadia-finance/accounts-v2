/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { StakingAM } from "../../../../src/asset-modules/abstracts/AbstractStakingAM.sol";

/**
 * @notice Fuzz tests for the function "_getRewardBalances" of contract "StakingAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetRewardBalances_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_getRewardBalances_NonZeroTotalStaked_OverflowDeltaRewardPerToken_MulDivDown(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint256 currentRewardGlobal,
        uint96 positionId,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public {
        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // more than 1gwei is staked.
        assetState.totalStaked = uint128(bound(assetState.totalStaked, 1, type(uint128).max));

        // And: deltaRewardPerToken mulDivDown overflows.
        currentRewardGlobal = bound(currentRewardGlobal, type(uint256).max / 1e18 + 1, type(uint256).max);

        // And: State is persisted.
        givenValidStakingAMState(surplusState);
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);
        stakingAM.setActualRewardBalance(asset, currentRewardGlobal);

        // When: Calling _getRewardBalances().
        // Then: transaction reverts in safe cast.
        StakingAM.AssetState memory assetState_ = StakingAM.AssetState({
            allowed: true,
            lastRewardPerTokenGlobal: assetState.lastRewardPerTokenGlobal,
            totalStaked: assetState.totalStaked
        });
        vm.expectRevert(bytes(""));
        stakingAM.getRewardBalances(assetState_, positionState, currentRewardGlobal);
    }

    function testFuzz_Revert_getRewardBalances_NonZeroTotalStaked_OverflowDeltaRewardPosition(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint96 positionId,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public {
        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // Given: More than 1e18 is staked, the delta reward of the position can not overflow otherwise.
        assetState.totalStaked = uint128(bound(assetState.totalStaked, 1e18 + 1, type(uint128).max));

        // And: totalStaked should be >= to amountStakedForPosition (invariant).
        positionState.amountStaked = uint128(bound(positionState.amountStaked, 1e18 + 1, assetState.totalStaked));

        // And: the reward stays below the amount that makes the mulDivDown of the delta revert.
        assetState.currentRewardGlobal = bound(assetState.currentRewardGlobal, 1, type(uint256).max / 1e18);

        // Calculate the new rewardPerTokenGlobal.
        uint128 rewardPerToken = currentRewardPerTokenGlobal(assetState);

        // And: deltaReward of the position is bigger than type(uint128).max (overflow).
        uint256 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = rewardPerToken - positionState.lastRewardPerTokenPosition;
        }
        deltaRewardPerToken = bound(
            deltaRewardPerToken, type(uint128).max * uint256(1e18 + 1) / positionState.amountStaked, type(uint128).max
        );
        unchecked {
            positionState.lastRewardPerTokenPosition = rewardPerToken - uint128(deltaRewardPerToken);
        }

        // And: State is persisted.
        givenValidStakingAMState(surplusState);
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);

        // When: Calling _getRewardBalances().
        // Then: transaction reverts in safe cast.
        StakingAM.AssetState memory assetState_ = StakingAM.AssetState({
            allowed: true,
            lastRewardPerTokenGlobal: assetState.lastRewardPerTokenGlobal,
            totalStaked: assetState.totalStaked
        });
        vm.expectRevert(bytes(""));
        stakingAM.getRewardBalances(assetState_, positionState, assetState.currentRewardGlobal);
    }

    function testFuzz_Revert_getRewardBalances_NonZeroTotalStaked_OverflowLastRewardPosition(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint96 positionId,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public {
        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // And: more than 1 gwei is staked.
        assetState.totalStaked = uint128(bound(assetState.totalStaked, 1, type(uint128).max));

        // And: totalStaked should be >= to amountStakedForPosition (invariant).
        positionState.amountStaked = uint128(bound(positionState.amountStaked, 1, assetState.totalStaked));

        // And: the reward stays below the amount that makes the mulDivDown of the delta revert.
        assetState.currentRewardGlobal = bound(assetState.currentRewardGlobal, 1, type(uint256).max / 1e18);

        // Calculate the new rewardPerTokenGlobal.
        uint128 rewardPerToken = currentRewardPerTokenGlobal(assetState);

        // And: previously earned rewards for Account + new rewards overflow.
        // -> deltaReward must be greater as 1
        uint256 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = rewardPerToken - positionState.lastRewardPerTokenPosition;
        }
        deltaRewardPerToken = bound(deltaRewardPerToken, 1e18 / positionState.amountStaked + 1, type(uint128).max);
        unchecked {
            positionState.lastRewardPerTokenPosition = rewardPerToken - uint128(deltaRewardPerToken);
        }
        uint256 deltaReward = deltaRewardPerToken * positionState.amountStaked / 1e18;
        positionState.lastRewardPosition = uint128(
            bound(
                positionState.lastRewardPosition,
                deltaReward > type(uint128).max ? 0 : type(uint128).max - deltaReward + 1,
                type(uint128).max
            )
        );

        // And: State is persisted.
        givenValidStakingAMState(surplusState);
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);

        // When: Calling _getRewardBalances().
        // Then: transaction reverts in safe cast.
        StakingAM.AssetState memory assetState_ = StakingAM.AssetState({
            allowed: true,
            lastRewardPerTokenGlobal: assetState.lastRewardPerTokenGlobal,
            totalStaked: assetState.totalStaked
        });
        vm.expectRevert(bytes(""));
        stakingAM.getRewardBalances(assetState_, positionState, assetState.currentRewardGlobal);
    }

    function testFuzz_Success_getRewardBalances_NonZeroTotalStaked_CapDeltaRewardPerToken(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint256 currentRewardGlobal,
        uint96 positionId,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public {
        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // And: more than 1 gwei is staked.
        assetState.totalStaked = uint128(bound(assetState.totalStaked, 1, type(uint128).max));

        // And: deltaRewardPerToken is bigger as type(uint128).max (capped instead of reverting).
        uint256 lowerBound = (uint256(type(uint128).max) + 1) * assetState.totalStaked / 1e18 + 1;
        currentRewardGlobal = bound(currentRewardGlobal, lowerBound, type(uint256).max / 1e18);

        // And: the new RewardPerToken of the asset, with deltaRewardPerToken capped.
        uint128 rewardPerToken;
        unchecked {
            rewardPerToken = assetState.lastRewardPerTokenGlobal + type(uint128).max;
        }

        // And: the rewards earned by the position since its last interaction.
        uint128 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = rewardPerToken - positionState.lastRewardPerTokenPosition;
        }

        // And: the position holds any amount up to totalStaked whose delta reward fits its uint128 reward balance.
        uint256 maxAmountStaked = assetState.totalStaked;
        if (deltaRewardPerToken > 0) {
            uint256 maxForDelta = uint256(type(uint128).max) * 1e18 / deltaRewardPerToken;
            if (maxForDelta < maxAmountStaked) maxAmountStaked = maxForDelta;
        }
        positionState.amountStaked = uint128(bound(positionState.amountStaked, 0, maxAmountStaked));
        uint256 deltaReward = uint256(deltaRewardPerToken) * positionState.amountStaked / 1e18;

        // And: the reward balance of the position does not overflow.
        positionState.lastRewardPosition =
            uint128(bound(positionState.lastRewardPosition, 0, type(uint128).max - deltaReward));

        // And: State is persisted.
        givenValidStakingAMState(surplusState);
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);
        stakingAM.setActualRewardBalance(asset, currentRewardGlobal);

        // When : Calling _getRewardBalances().
        StakingAM.AssetState memory assetState_ = StakingAM.AssetState({
            allowed: true,
            lastRewardPerTokenGlobal: assetState.lastRewardPerTokenGlobal,
            totalStaked: assetState.totalStaked
        });
        StakingAM.PositionState memory positionState_;
        (assetState_, positionState_) = stakingAM.getRewardBalances(assetState_, positionState, currentRewardGlobal);

        // Then : deltaRewardPerToken is capped at type(uint128).max.
        assertEq(assetState_.lastRewardPerTokenGlobal, rewardPerToken);
        assertEq(assetState_.totalStaked, assetState.totalStaked);

        // And : the capped delta is credited to the position.
        assertEq(positionState_.asset, positionState.asset);
        assertEq(positionState_.amountStaked, positionState.amountStaked);
        assertEq(positionState_.lastRewardPerTokenPosition, rewardPerToken);
        assertEq(positionState_.lastRewardPosition, positionState.lastRewardPosition + deltaReward);
    }

    function testFuzz_Success_getRewardBalances_ZeroTotalStaked(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint96 positionId,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public {
        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // Given : Valid state
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max);

        // And: State is persisted.
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);

        // And: totalStaked is zero.
        stakingAM.setTotalStaked(asset, 0);
        assetState.totalStaked = 0;

        // When : Calling _getRewardBalances().
        StakingAM.AssetState memory assetState_ = StakingAM.AssetState({
            allowed: true,
            lastRewardPerTokenGlobal: assetState.lastRewardPerTokenGlobal,
            totalStaked: assetState.totalStaked
        });
        StakingAM.PositionState memory positionState_;
        (assetState_, positionState_) =
            stakingAM.getRewardBalances(assetState_, positionState, assetState.currentRewardGlobal);

        // Then : It should return the correct values
        assertEq(positionState_.asset, positionState.asset);
        assertEq(positionState_.amountStaked, positionState.amountStaked);
        assertEq(positionState_.lastRewardPerTokenPosition, assetState.lastRewardPerTokenGlobal);
        assertEq(positionState_.lastRewardPosition, positionState.lastRewardPosition);

        assertEq(assetState_.lastRewardPerTokenGlobal, assetState.lastRewardPerTokenGlobal);
        assertEq(assetState_.totalStaked, assetState.totalStaked);
    }

    function testFuzz_Success_getRewardBalances_NonZeroTotalStaked(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        uint96 positionId,
        StakingAMStateForSurplus memory surplusState,
        uint8 assetDecimals
    ) public {
        // Given : Add an asset
        address asset = addAsset(assetDecimals);

        // Given : Valid state
        (assetState, positionState) =
            givenValidStakingAMState(assetState, positionState, surplusState, 0, type(uint128).max);

        // And: State is persisted.
        setStakingAMState(assetState, positionState, surplusState, asset, positionId);

        // When : Calling _getRewardBalances().
        StakingAM.AssetState memory assetState_ = StakingAM.AssetState({
            allowed: true,
            lastRewardPerTokenGlobal: assetState.lastRewardPerTokenGlobal,
            totalStaked: assetState.totalStaked
        });
        StakingAM.PositionState memory positionState_;
        (assetState_, positionState_) =
            stakingAM.getRewardBalances(assetState_, positionState, assetState.currentRewardGlobal);

        // Then : It should return the correct values
        uint128 rewardPerToken = currentRewardPerTokenGlobal(assetState);
        uint128 deltaRewardPerToken;
        unchecked {
            deltaRewardPerToken = rewardPerToken - positionState.lastRewardPerTokenPosition;
        }
        uint256 deltaReward = uint256(positionState.amountStaked).mulDivDown(deltaRewardPerToken, 1e18);

        // Then : It should return the correct values
        assertEq(positionState_.asset, positionState.asset);
        assertEq(positionState_.amountStaked, positionState.amountStaked);
        assertEq(positionState_.lastRewardPerTokenPosition, rewardPerToken);
        assertEq(positionState_.lastRewardPosition, positionState.lastRewardPosition + deltaReward);

        assertEq(assetState_.lastRewardPerTokenGlobal, rewardPerToken);
        assertEq(assetState_.totalStaked, assetState.totalStaked);
    }
}
