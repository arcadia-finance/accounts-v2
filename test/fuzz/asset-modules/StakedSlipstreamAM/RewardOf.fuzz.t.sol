/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "rewardOf" of contract "StakedSlipstreamAM".
 */
contract RewardOf_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_rewardOf_InRange(
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
        uint256 rewards = stakedSlipstreamAM.rewardOf(assetId);

        // Then: The share of the position in the reward growth since it was staked is returned.
        uint256 rewardGrowthInsideX128;
        unchecked {
            rewardGrowthInsideX128 = rewardGrowthGlobalX128Current - rewardGrowthGlobalX128Last;
        }
        assertEq(rewards, FullMath.mulDiv(rewardGrowthInsideX128, getActualLiquidity(position), FixedPoint128.Q128));
    }

    function testFuzz_Success_rewardOf_BelowRange(
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
        uint256 rewards = stakedSlipstreamAM.rewardOf(assetId);

        // Then: The position earned nothing.
        assertEq(rewards, 0);
    }

    function testFuzz_Success_rewardOf_AboveRange(
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
        uint256 rewards = stakedSlipstreamAM.rewardOf(assetId);

        // Then: The position earned nothing.
        assertEq(rewards, 0);
    }
}
