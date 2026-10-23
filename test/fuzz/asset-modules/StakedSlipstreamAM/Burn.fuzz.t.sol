/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../../lib/solmate/src/tokens/ERC721.sol";
import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "StakedSlipstreamAM".
 */
contract Burn_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
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
    function testFuzz_Revert_burn_NonExistingId(uint256 assetId, address sender) public {
        // Given: The asset id is not staked, so its owner reads as the zero address.

        // And: The sender is the caller, which the zero address can never be.
        vm.assume(sender != address(0));
        vm.prank(sender);

        // When: The sender burns the position.
        // Then: It reverts.
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedSlipstreamAM.burn(assetId);
    }

    function testFuzz_Revert_burn_NonOwner(
        StakedSlipstreamAM.PositionState memory position,
        address nonOwner,
        int24 tick
    ) public {
        // Given: A staked position of the liquidity provider.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);
        position = givenValidPosition(position);
        uint256 assetId = _stakePosition(position);

        // And: The sender is not the owner of the position.
        vm.assume(nonOwner != users.liquidityProvider);

        // When: The sender burns the position.
        // Then: It reverts.
        vm.prank(nonOwner);
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedSlipstreamAM.burn(assetId);
    }

    function testFuzz_Success_burn_NonZeroReward(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthDeltaX128,
        int24 tick
    ) public {
        // Given: A valid position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);

        // And: An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        // And: The position is staked.
        uint256 assetId = _stakePosition(position);

        // And: The reward is not zero and fits the uint128 the RewardPaid event narrows it to.
        uint256 liquidity = getActualLiquidity(position);
        rewardGrowthDeltaX128 = bound(
            rewardGrowthDeltaX128,
            FixedPoint128.Q128 / liquidity + 1,
            FullMath.mulDiv(type(uint128).max - 1, FixedPoint128.Q128, liquidity)
        );
        uint256 rewardsExpected = FullMath.mulDiv(rewardGrowthDeltaX128, liquidity, FixedPoint128.Q128);

        // And: The gauge holds the reward token and the pool has the reserve to pay any reward.
        deal(AERO, address(gauge), type(uint256).max, true);
        stdstore.target(address(pool)).sig(pool.rewardReserve.selector).checked_write(type(uint256).max);

        // And: The reward is earned.
        vm.warp(block.timestamp + 1);
        uint256 rewardGrowthGlobalX128Current;
        unchecked {
            rewardGrowthGlobalX128Current = rewardGrowthGlobalX128Last + rewardGrowthDeltaX128;
        }
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When: The liquidity provider burns the position.
        // Then: The Transfer and the RewardPaid events are emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedSlipstreamAM));
        emit ERC721.Transfer(users.liquidityProvider, address(0), assetId);
        vm.expectEmit(address(stakedSlipstreamAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, AERO, uint128(rewardsExpected));
        uint256 rewards = stakedSlipstreamAM.burn(assetId);

        // And: The reward is returned and paid to the owner.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(AERO).balanceOf(users.liquidityProvider), rewardsExpected);

        // And: The position is transferred back to the owner.
        assertEq(slipstreamPositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_burn_ZeroReward(StakedSlipstreamAM.PositionState memory position, int24 tick) public {
        // Given: A staked position of the liquidity provider, on a gauge that accrued nothing.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);
        position = givenValidPosition(position, 1);
        uint256 assetId = _stakePosition(position);

        // When: The liquidity provider burns the position.
        // Then: The Transfer event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedSlipstreamAM));
        emit ERC721.Transfer(users.liquidityProvider, address(0), assetId);
        uint256 rewards = stakedSlipstreamAM.burn(assetId);

        // And: No reward is returned.
        assertEq(rewards, 0);

        // And: The position is transferred back to the owner.
        assertEq(slipstreamPositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_burn_BookedSurplusNotPaid(
        StakedSlipstreamAM.PositionState memory position,
        uint256 reward,
        uint256 booked,
        int24 tick,
        address recipient
    ) public {
        // Given: A staked position with a reward earned.
        (uint256 assetId, uint256 earned) = _initStakedPositionWithEarned(position, tick, reward, recipient);

        // And: The hook will book a part of the delivery for the recipient.
        booked = bound(booked, 1, earned);
        stakedSlipstreamAM.setBookedAmount(booked);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedSlipstreamAM.burn(assetId);

        // Then: The owner is paid the delivery less the booked part.
        assertEq(rewards, earned - booked);
        assertEq(ERC20(AERO).balanceOf(users.liquidityProvider), earned - booked);

        // And: The booked part stays claimable for the recipient.
        assertEq(stakedSlipstreamAM.claimableSurplus(), booked);
    }

    function testFuzz_Success_burn_DonationNotPaid(
        StakedSlipstreamAM.PositionState memory position,
        uint256 reward,
        uint128 donation,
        int24 tick,
        address recipient
    ) public {
        // Given: A staked position with a reward earned.
        (uint256 assetId, uint256 earned) = _initStakedPositionWithEarned(position, tick, reward, recipient);

        // And: Reward tokens reached the Asset Module outside an interaction.
        // forge-lint: disable-next-item(unsafe-typecast)
        donation = uint128(bound(donation, 1, type(uint128).max));
        deal(AERO, address(stakedSlipstreamAM), donation, false);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedSlipstreamAM.burn(assetId);

        // Then: The owner is paid the delivery alone.
        assertEq(rewards, earned);
        assertEq(ERC20(AERO).balanceOf(users.liquidityProvider), earned);

        // And: The donation stays claimable for the recipient.
        assertEq(stakedSlipstreamAM.claimableSurplus(), donation);
    }
}
