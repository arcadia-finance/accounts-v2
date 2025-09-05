/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "claimReward" of contract "StakedSlipstreamAM".
 */
contract ClaimReward_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
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
    function testFuzz_Revert_claimReward_NonExistingId(uint256 assetId) public {
        // Given: assetId is not staked.

        // When: sender claims rewards.
        // Then: Transaction reverts.
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedSlipstreamAM.claimReward(assetId);
    }

    function testFuzz_Revert_claimReward_NonOwner(StakedSlipstreamAM.PositionState memory position, address nonOwner)
        public
    {
        // Given: sender is not the owner.
        vm.assume(nonOwner != users.liquidityProvider);

        // And: assetId is minted.
        deployAndAddGauge(0);
        position = givenValidPosition(position);
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // When: sender claims rewards.
        // Then: Transaction reverts.
        vm.prank(nonOwner);
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedSlipstreamAM.claimReward(assetId);
    }

    function testFuzz_Success_claimReward_NonZeroReward(
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
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector).checked_write(
            rewardGrowthGlobalX128Last
        );

        // And : assetId is minted.
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // And : Rewards are earned.
        vm.warp(block.timestamp + 1);
        deal(AERO, address(gauge), type(uint256).max, true);
        stdstore.target(address(pool)).sig(pool.rewardReserve.selector).checked_write(type(uint256).max);
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector).checked_write(
            rewardGrowthGlobalX128Current
        );

        // And : Rewards amount is not zero.
        uint256 rewardGrowthInsideX128;
        unchecked {
            rewardGrowthInsideX128 = rewardGrowthGlobalX128Current - rewardGrowthGlobalX128Last;
        }
        uint256 liquidity = getActualLiquidity(position);
        uint256 rewardsExpected = FullMath.mulDiv(rewardGrowthInsideX128, liquidity, FixedPoint128.Q128);
        vm.assume(rewardsExpected > 0);

        // When : Owner calls claimReward.
        // Then : correct event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit();
        emit StakedSlipstreamAM.RewardPaid(assetId, AERO, uint128(rewardsExpected));
        uint256 rewards = stakedSlipstreamAM.claimReward(assetId);

        // Then : The correct rewards amount is returned.
        assertEq(rewards, rewardsExpected);

        // And: Balance of owner increased.
        assertEq(ERC20(AERO).balanceOf(users.liquidityProvider), rewardsExpected);
    }

    function testFuzz_Success_claimReward_ZeroReward(StakedSlipstreamAM.PositionState memory position) public {
        // Given : a valid position.
        position = givenValidPosition(position, 1);
        deployAndAddGauge(0);

        // And : assetId is minted.
        uint256 assetId = addLiquidity(position);

        // And: Position is staked.
        vm.startPrank(users.liquidityProvider);
        slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
        stakedSlipstreamAM.mint(assetId);
        vm.stopPrank();

        // When : claimReward is called.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedSlipstreamAM.claimReward(assetId);

        // Then : The 0 rewards amount is returned.
        assertEq(rewards, 0);
    }
}
