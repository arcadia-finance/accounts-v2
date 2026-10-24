/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "rewardOf" of contract "StakedMetadex03CLAM".
 */
contract RewardOf_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_rewardOf_Leaf_ChainSuspended(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position whose emissions exceed the wei its share can round away.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        assertGt(stakedMetadex03CLAM.rewardOf(assetId), 0);

        // And: The chain can no longer mint.
        setChainSuspended(true);

        // When: The reward of the position is read.
        // Then: Nothing is credited, a claim could not deliver it.
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);
    }

    function testFuzz_Success_rewardOf_Root_BelowMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthDeltaX128,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, staked at a non zero reward growth.
        uint256 assetId = _stakeRootPosition(position, tick, rewardGrowthGlobalX128Last);

        // And: The growth since the stake is capped so the earned amount stays below the redeem floor.
        uint256 maxDelta = FullMath.mulDiv(MIN_REDEEM_AMOUNT - 1, FixedPoint128.Q128, getActualLiquidity(position));
        rewardGrowthDeltaX128 = bound(rewardGrowthDeltaX128, 0, maxDelta);
        uint256 rewardGrowthGlobalX128Current;
        unchecked {
            rewardGrowthGlobalX128Current = rewardGrowthGlobalX128Last + rewardGrowthDeltaX128;
        }
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);
        assertLt(_earned(position, rewardGrowthGlobalX128Last, rewardGrowthGlobalX128Current), MIN_REDEEM_AMOUNT);

        // When: The reward of the position is read.
        // Then: Nothing is valued, the root handler defers a sub floor total instead of delivering it.
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);
    }

    function testFuzz_Success_rewardOf_Leaf_InRange(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current,
        int24 tick
    ) public {
        // Given: A valid position.
        position = givenValidPosition(position, 1);

        // And: The current tick of the pool is in the range of the position, which excludes its tickUpper.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);

        // And: An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        // And: The position is staked.
        uint256 assetId = _stakePosition(position);

        // And: The reward growth of the pool moved.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When: The reward of the position is read.
        uint256 rewards = stakedMetadex03CLAM.rewardOf(assetId);

        // Then: The share of the position in the reward growth since it was staked is returned.
        assertEq(rewards, _earned(position, rewardGrowthGlobalX128Last, rewardGrowthGlobalX128Current));
    }

    function testFuzz_Success_rewardOf_Root_AboveMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthDeltaX128,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, staked at a non zero reward growth.
        uint256 assetId = _stakeRootPosition(position, tick, rewardGrowthGlobalX128Last);

        // And: The growth since the stake lifts the earned amount to the redeem floor.
        uint256 minDelta = FullMath.mulDiv(MIN_REDEEM_AMOUNT, FixedPoint128.Q128, getActualLiquidity(position)) + 1;
        rewardGrowthDeltaX128 = bound(rewardGrowthDeltaX128, minDelta, type(uint256).max);
        uint256 rewardGrowthGlobalX128Current;
        unchecked {
            rewardGrowthGlobalX128Current = rewardGrowthGlobalX128Last + rewardGrowthDeltaX128;
        }
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);
        uint256 rewardsExpected = _earned(position, rewardGrowthGlobalX128Last, rewardGrowthGlobalX128Current);
        assertGe(rewardsExpected, MIN_REDEEM_AMOUNT);

        // When: The reward of the position is read.
        // Then: The full earned amount is valued.
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), rewardsExpected);
    }

    function testFuzz_Success_rewardOf_Leaf_BelowRange(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current,
        int24 tick
    ) public {
        // Given: A valid position, with a tick below its tickLower left for the current tick.
        // forge-lint: disable-next-item(unsafe-typecast)
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK + 1, TickMath.MAX_TICK - 1));
        // forge-lint: disable-next-item(unsafe-typecast)
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK));
        position = givenValidPosition(position, 1);

        // And: The current tick of the pool is below the range, which includes its tickLower.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, position.tickLower - 1));
        deployAndAddGauge(tick);

        // And: An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        // And: The position is staked.
        uint256 assetId = _stakePosition(position);

        // And: The reward growth of the pool moved.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When: The reward of the position is read.
        uint256 rewards = stakedMetadex03CLAM.rewardOf(assetId);

        // Then: The position earned nothing.
        assertEq(rewards, 0);
    }

    function testFuzz_Success_rewardOf_Leaf_AboveRange(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current,
        int24 tick
    ) public {
        // Given: A valid position, with a tick above its tickUpper left for the current tick.
        // forge-lint: disable-next-item(unsafe-typecast)
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 2));
        // forge-lint: disable-next-item(unsafe-typecast)
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK - 1));
        position = givenValidPosition(position, 1);

        // And: The current tick is above the range, and below the MAX_TICK a pool cannot be initialised at.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickUpper, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // And: An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        // And: The position is staked.
        uint256 assetId = _stakePosition(position);

        // And: The reward growth of the pool moved.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When: The reward of the position is read.
        uint256 rewards = stakedMetadex03CLAM.rewardOf(assetId);

        // Then: The position earned nothing.
        assertEq(rewards, 0);
    }

    function testFuzz_Success_rewardOf_Leaf_ExcludesDeferredRewards(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: The gauge deferred the emissions of a burned position, over the wei rounding can take.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        position = _givenPositionWithRoomAbove(position);
        assertGt(_stakeAndDeferEmissions(position, emissions, tick), 0);

        // And: A position is staked above the current tick, earning nothing of its own.
        uint256 assetId = _stakeIdlePositionAbove(position);

        // When: The reward of the position is read.
        // Then: The deferred emissions, shared by every position, are not valued as its own.
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);
    }

    function testFuzz_Success_rewardOf_Root_ExcludesDeferredRewards(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsBurned,
        uint256 emissionsStaked,
        int24 tick
    ) public {
        // Given: A gauge on the root chain deferred the emissions of a burned position, over the redeem floor.
        _stageRoot();
        emissionsBurned = bound(emissionsBurned, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        position = _givenPositionStakedTwice(position);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissionsBurned, tick);
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A second position is staked over the same range, accruing less than the floor of its own.
        uint256 assetId = _stakePosition(position);
        emissionsStaked = bound(emissionsStaked, 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(gauge), emissionsStaked);
        vm.warp(block.timestamp + 1);

        // And: The gross earned amount, which the gauge reports including the deferred emissions, clears the floor.
        uint256 gross = gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId));
        assertGe(gross, MIN_REDEEM_AMOUNT);
        assertGt(gross - deferredEmissions, 0);
        assertLt(gross - deferredEmissions, MIN_REDEEM_AMOUNT);

        // When: The reward of the position is read.
        // Then: Nothing is valued, the own share of the position alone stays below the floor.
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);

        // And: A claim of the position delivers nothing.
        vm.prank(users.liquidityProvider);
        assertEq(stakedMetadex03CLAM.claimReward(assetId), 0);
    }

    function testFuzz_Success_rewardOf_Root_PendingCompletesFloor(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsHeld,
        uint256 emissionsStaked,
        int24 tick
    ) public {
        // Given: A claim on the root chain left a sub floor amount with the emissions handler.
        emissionsHeld = bound(emissionsHeld, 4, MIN_REDEEM_AMOUNT - 1);
        uint256 assetId = _initRootPositionWithEarned(position, emissionsHeld, tick);
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.claimReward(assetId);
        uint256 held = pendingRedeemsOf(address(stakedMetadex03CLAM));
        vm.assume(held > 2);

        // And: The position accrues less than the floor, but enough to release the held amount.
        emissionsStaked = bound(emissionsStaked, MIN_REDEEM_AMOUNT - held + 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(gauge), emissionsStaked);
        vm.warp(block.timestamp + 1);
        uint256 own = gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId));
        vm.assume(own < MIN_REDEEM_AMOUNT && own + held >= MIN_REDEEM_AMOUNT);

        // When: The reward of the position is read.
        // Then: The own share is valued, a claim releases it together with the held amount.
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), own);

        // And: A claim of the position delivers its own share.
        vm.prank(users.liquidityProvider);
        assertEq(stakedMetadex03CLAM.claimReward(assetId), own);
    }
}
