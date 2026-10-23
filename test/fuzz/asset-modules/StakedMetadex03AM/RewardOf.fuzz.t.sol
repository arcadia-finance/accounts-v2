/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedMetadex03AM_Fuzz_Test, StakingAM } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "rewardOf" of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract RewardOf_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_rewardOf(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint96 positionId
    ) public {
        // Given: The pool and its gauge are onboarded.
        _addGauge();

        // And: A valid state is persisted for a non-zero position.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // When: Calling rewardOf().
        uint256 reward = stakedMetadex03AM.rewardOf(positionId);

        // Then: It returns the credited reward plus what the staker of the position earned.
        assertEq(reward, uint256(positionState.lastRewardPosition) + assetState.currentRewardGlobal);
    }

    function testFuzz_Success_rewardOf_Root_BelowMinRedeemAmount(
        StakingAMStateForAsset memory assetState,
        StakingAM.PositionState memory positionState,
        StakingAMStateForSurplus memory surplusState,
        uint96 positionId
    ) public {
        // Given: The protocol is staged on the root chain, with an onboarded gauge.
        _stageMetadex03(true);
        _addGauge();

        // And: A valid state, of which the staker earned less than the redeem floor.
        givenValidStakingAMStateMetadex03(assetState, positionState, surplusState);
        assetState.currentRewardGlobal = bound(assetState.currentRewardGlobal, 0, MIN_REDEEM_AMOUNT - 1);

        // And: The state is persisted for a non-zero position.
        positionId = uint96(bound(positionId, 1, type(uint96).max));
        setStakedMetadex03AMState(assetState, positionState, surplusState, address(metadex03Pool), positionId);

        // When: Calling rewardOf().
        uint256 reward = stakedMetadex03AM.rewardOf(positionId);

        // Then: It returns the credited reward alone.
        assertEq(reward, positionState.lastRewardPosition);
    }

    function testFuzz_Success_rewardOf_PenaltyActive_NetEarnedOfOwnStaker(
        uint128 amount,
        uint128 amountOther,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        uint256 minStakeBlocks,
        uint256 penaltyRate
    ) public {
        // Given: Two positions minted in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);
        amount = uint128(bound(amount, 1, type(uint128).max / 3));
        amountOther = uint128(bound(amountOther, 1, type(uint128).max / 3));
        uint256 positionId = _mintPosition(users.accountOwner, amount);
        uint256 positionIdOther = _mintPosition(users.liquidityProvider, amountOther);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: Emissions accrue and the penalty windows of both positions close.
        emissionsFirst = bound(emissionsFirst, 0, type(uint128).max / 2);
        addEmissionsToGauge(address(metadex03Gauge), emissionsFirst);
        vm.roll(block.number + minStakeBlocks);

        // And: An increase credits what the staker earned and opens the window of the position.
        uint256 credited = metadex03Gauge.earned(staker);
        _increasePosition(users.accountOwner, positionId, amount);

        // And: More emissions accrue inside the window of the position.
        emissionsSecond = bound(emissionsSecond, 0, type(uint128).max - emissionsFirst);
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);

        // When: Calling rewardOf() for both positions.
        // Then: Each returns its credited reward plus the net earned emissions of its own staker.
        assertEq(stakedMetadex03AM.rewardOf(positionId), credited + metadex03Gauge.earned(staker));
        assertEq(
            stakedMetadex03AM.rewardOf(positionIdOther),
            metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther))
        );
    }
}
