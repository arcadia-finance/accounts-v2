/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
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
        // Given : a valid position.
        position = givenValidPosition(position, 1);

        // And : the current tick of the pool is in range (can't be equal to tickUpper, but can be equal to tickLower).
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);

        // Given : An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        // And : assetId is minted.
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // And : Rewards are earned.
        stdstore.target(address(pool)).sig(pool.rewardReserve.selector).checked_write(type(uint256).max);
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When : rewardOf is called.
        uint256 rewards = stakedSlipstreamAM.rewardOf(assetId);

        // Then : The correct rewards amount is returned.
        uint256 rewardGrowthInsideX128;
        unchecked {
            rewardGrowthInsideX128 = rewardGrowthGlobalX128Current - rewardGrowthGlobalX128Last;
        }
        uint256 liquidity = getActualLiquidity(position);
        uint256 rewardsExpected = FullMath.mulDiv(rewardGrowthInsideX128, liquidity, FixedPoint128.Q128);
        assertEq(rewards, rewardsExpected);
    }

    function testFuzz_Success_rewardOf_BelowRange(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current,
        int24 tick
    ) public {
        // Given : a valid position.
        position = givenValidPosition(position, 1);

        // And : the current tick is below the range (for UniV3, tickLower is considered in range).
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK + 1, TickMath.MAX_TICK - 1));
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK));
        tick = int24(bound(tick, TickMath.MIN_TICK, position.tickLower - 1));
        deployAndAddGauge(tick);

        // Given : An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        // And : assetId is minted.
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // And : Rewards are earned.
        stdstore.target(address(pool)).sig(pool.rewardReserve.selector).checked_write(type(uint256).max);
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When : rewardOf is called.
        uint256 rewards = stakedSlipstreamAM.rewardOf(assetId);

        // Then : The 0 rewards amount is returned.
        assertEq(rewards, 0);
    }

    function testFuzz_Success_rewardOf_AboveRange(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current,
        int24 tick
    ) public {
        // Given : a valid position.
        position = givenValidPosition(position, 1);

        // And : the current tick is above the range (for UniV3, tickUpper is considered out range).
        // But a pool cannot be initiated at MAX_TICK (reverts with "R")
        position.tickLower = int24(bound(position.tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 2));
        position.tickUpper = int24(bound(position.tickUpper, position.tickLower + 1, TickMath.MAX_TICK - 1));
        tick = int24(bound(tick, position.tickUpper, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);

        // Given : An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        // And : assetId is minted.
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // And : Rewards are earned.
        stdstore.target(address(pool)).sig(pool.rewardReserve.selector).checked_write(type(uint256).max);
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When : rewardOf is called.
        uint256 rewards = stakedSlipstreamAM.rewardOf(assetId);

        // Then : The 0 rewards amount is returned.
        assertEq(rewards, 0);
    }
}
