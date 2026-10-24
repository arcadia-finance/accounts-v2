/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { ILeafVoter } from "../../../utils/fixtures/metadex03/interfaces/ILeafVoter.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "claimReward" of contract "StakedMetadex03CLAM".
 */
contract ClaimReward_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
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
    function testFuzz_Revert_claimReward_NonExistingId(uint256 assetId, address sender) public {
        // Given: The asset id is not staked, so its owner reads as the zero address.

        // And: The sender is not the zero address, which can never be a caller.
        vm.assume(sender != address(0));

        // When: The sender claims the reward.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedMetadex03CLAM.claimReward(assetId);
    }

    function testFuzz_Revert_claimReward_NonOwner(
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

        // When: The sender claims the reward.
        // Then: It reverts.
        vm.prank(nonOwner);
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedMetadex03CLAM.claimReward(assetId);
    }

    function testFuzz_Revert_claimReward_ChainSuspended_DeferredRewards(
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
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);

        // And: The chain is suspended.
        setChainSuspended(true);

        // When: The liquidity provider claims the reward.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03CLAM.claimReward(assetId);
    }

    function testFuzz_Revert_claimReward_ChainSuspended_NonZeroEarned(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position whose emissions exceed the wei its share can round away.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        assertGt(stakedMetadex03CLAM.rewardOf(assetId), 0);

        // And: The chain is suspended.
        setChainSuspended(true);

        // When: The liquidity provider claims the reward.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03CLAM.claimReward(assetId);
    }

    function testFuzz_Revert_claimReward_GaugeTapeGasLimit(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address gaugeTape
    ) public {
        // Given: A staked position with earned emissions.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);

        // And: A gauge tape whose gas limit exceeds the gas left in the call.
        vm.assume(gaugeTape != address(0));
        metadex03CLGaugeFactory.setClGaugeTape(gaugeTape, type(uint32).max);

        // When: The liquidity provider claims the reward.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(bytes("GL"));
        stakedMetadex03CLAM.claimReward{ gas: 10_000_000 }(assetId);
    }

    function testFuzz_Success_claimReward_Leaf_NonZeroReward(
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

        // And: The emissions entitlement of the gauge on the LeafVoter covers the reward.
        addEmissionsToGaugeMetadex03CL(pool, address(gauge), rewardsExpected);

        // And: The reward is earned.
        vm.warp(block.timestamp + 1);
        uint256 rewardGrowthGlobalX128Current;
        unchecked {
            rewardGrowthGlobalX128Current = rewardGrowthGlobalX128Last + rewardGrowthDeltaX128;
        }
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When: The liquidity provider claims the reward.
        // Then: The RewardPaid event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, receiptToken, uint128(rewardsExpected));
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // And: The reward is returned and paid to the owner.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), rewardsExpected);
    }

    function testFuzz_Success_claimReward_Root_NonZeroReward(
        StakedSlipstreamAM.PositionState memory position,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthDeltaX128,
        int24 tick
    ) public {
        // Given: A position staked on the root chain, at an initial rewardGrowthGlobalX128.
        uint256 assetId = _stakeRootPosition(position, tick, rewardGrowthGlobalX128Last);

        // And: The reward clears the redeem floor and stays within the rate the Minter accrues at.
        uint256 liquidity = getActualLiquidity(position);
        rewardGrowthDeltaX128 = bound(
            rewardGrowthDeltaX128,
            FullMath.mulDiv(MIN_REDEEM_AMOUNT, FixedPoint128.Q128, liquidity) + 1,
            FullMath.mulDiv(MAX_BASE_RATE, FixedPoint128.Q128, liquidity)
        );
        uint256 rewardsExpected = FullMath.mulDiv(rewardGrowthDeltaX128, liquidity, FixedPoint128.Q128);
        assertGe(rewardsExpected, MIN_REDEEM_AMOUNT);

        // And: The emissions entitlement of the gauge on the LeafVoter covers the reward.
        addEmissionsToGaugeMetadex03CL(pool, address(gauge), rewardsExpected);

        // And: The reward is earned.
        vm.warp(block.timestamp + 1);
        uint256 rewardGrowthGlobalX128Current;
        unchecked {
            rewardGrowthGlobalX128Current = rewardGrowthGlobalX128Last + rewardGrowthDeltaX128;
        }
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Current);

        // When: The liquidity provider claims the reward.
        // Then: The RewardPaid event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, rootToken, uint128(rewardsExpected));
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // And: The reward is returned and paid to the owner in the Token, not in the ReceiptToken.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), rewardsExpected);

        // And: Neither side of the redeem is stuck in the Asset Module.
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Root_AboveMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, whose reward clears the redeem floor.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGe(rewardsExpected, MIN_REDEEM_AMOUNT);

        // When: The liquidity provider claims the reward.
        // Then: The RewardPaid event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, rootToken, uint128(rewardsExpected));
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // And: The ReceiptToken was redeemed for the Token, which the owner received.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), rewardsExpected);
    }

    function testFuzz_Success_claimReward_Leaf_ZeroReward(StakedSlipstreamAM.PositionState memory position, int24 tick)
        public
    {
        // Given: A staked position of the liquidity provider, on a gauge that accrued nothing.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);
        position = givenValidPosition(position, 1);
        uint256 assetId = _stakePosition(position);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: No reward is returned.
        assertEq(rewards, 0);
    }

    function testFuzz_Success_claimReward_Root_BelowMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, whose reward stays below the redeem floor.
        emissions = bound(emissions, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: Nothing is delivered, the root handler holds the sub floor total pending.
        assertEq(rewards, 0);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), 0);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), 0);

        // And: The gauge deferred nothing, the mint itself did not revert.
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Leaf_PenaltyActive_InsideWindow(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        int24 tick
    ) public {
        // Given: A staked position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        uint256 assetId = _stakePosition(position);

        // And: A penalty config is activated after onboarding, the claim is inside the window.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        metadex03CLGaugeFactory.setPenaltyConfig(minStakeBlocks, penaltyRate);

        // And: Emissions accrue after the stake.
        emissions = bound(emissions, 0, MAX_BASE_RATE);
        addEmissionsToGauge(address(gauge), emissions);
        vm.warp(block.timestamp + 1);

        // And: The valuation is the gross reward, haircut by the penalty.
        uint256 liquidity = getActualLiquidity(position);
        uint256 grossReward =
            FullMath.mulDiv(FullMath.mulDiv(emissions, FixedPoint128.Q128, liquidity), liquidity, FixedPoint128.Q128);
        uint256 netExpected = grossReward - grossReward * penaltyRate / MAX_PIPS;
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), netExpected);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: The haircut reward is returned and paid to the owner.
        assertEq(rewards, netExpected);
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), netExpected);
    }

    function testFuzz_Success_claimReward_Root_PenaltyActive_InsideWindow(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        int24 tick
    ) public {
        // Given: A position staked on the root chain, with the current tick of the pool in its range.
        _stageRoot();
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        uint256 assetId = _stakePosition(position);

        // And: A penalty config is activated after onboarding, the claim is inside the window.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS - 1);
        metadex03CLGaugeFactory.setPenaltyConfig(minStakeBlocks, penaltyRate);

        // And: Emissions accrue after the stake, enough for the haircut reward to clear the redeem floor.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT * MAX_PIPS / (MAX_PIPS - penaltyRate) + 2, MAX_BASE_RATE);
        addEmissionsToGauge(address(gauge), emissions);
        vm.warp(block.timestamp + 1);

        // And: The valuation is the gross reward, haircut by the penalty.
        uint256 liquidity = getActualLiquidity(position);
        uint256 grossReward =
            FullMath.mulDiv(FullMath.mulDiv(emissions, FixedPoint128.Q128, liquidity), liquidity, FixedPoint128.Q128);
        uint256 netExpected = grossReward - grossReward * penaltyRate / MAX_PIPS;
        assertGe(netExpected, MIN_REDEEM_AMOUNT);
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), netExpected);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: The haircut reward is returned and paid to the owner in the Token.
        assertEq(rewards, netExpected);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), netExpected);
    }

    function testFuzz_Success_claimReward_Leaf_PenaltyActive_OutsideWindow(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        int24 tick
    ) public {
        // Given: A staked position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        uint256 assetId = _stakePosition(position);

        // And: A penalty config is active but the penalty window of the position has passed.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        metadex03CLGaugeFactory.setPenaltyConfig(minStakeBlocks, penaltyRate);
        vm.roll(block.number + minStakeBlocks);

        // And: Emissions accrue after the stake.
        emissions = bound(emissions, 0, MAX_BASE_RATE);
        addEmissionsToGauge(address(gauge), emissions);
        vm.warp(block.timestamp + 1);

        // And: The valuation is the gross reward, without a haircut.
        uint256 liquidity = getActualLiquidity(position);
        uint256 grossReward =
            FullMath.mulDiv(FullMath.mulDiv(emissions, FixedPoint128.Q128, liquidity), liquidity, FixedPoint128.Q128);
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), grossReward);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: The full reward is returned and paid to the owner.
        assertEq(rewards, grossReward);
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), grossReward);
    }

    function testFuzz_Success_claimReward_Root_PenaltyActive_OutsideWindow(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        int24 tick
    ) public {
        // Given: A position staked on the root chain, with the current tick of the pool in its range.
        _stageRoot();
        position = givenValidPosition(position, 1);
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        deployAndAddGauge(tick);
        uint256 assetId = _stakePosition(position);

        // And: A penalty config is active but the penalty window of the position has passed.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        metadex03CLGaugeFactory.setPenaltyConfig(minStakeBlocks, penaltyRate);
        vm.roll(block.number + minStakeBlocks);

        // And: Emissions accrue after the stake, enough to clear the redeem floor.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        addEmissionsToGauge(address(gauge), emissions);
        vm.warp(block.timestamp + 1);

        // And: The valuation is the gross reward, without a haircut.
        uint256 liquidity = getActualLiquidity(position);
        uint256 grossReward =
            FullMath.mulDiv(FullMath.mulDiv(emissions, FixedPoint128.Q128, liquidity), liquidity, FixedPoint128.Q128);
        assertGe(grossReward, MIN_REDEEM_AMOUNT);
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), grossReward);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: The full reward is returned and paid to the owner in the Token.
        assertEq(rewards, grossReward);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), grossReward);
    }

    function testFuzz_Success_claimReward_Leaf_DeferredRewardsGoToRecipient(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The gauge deferred the emissions of a burned position, over the wei rounding can take.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        position = _givenPositionWithRoomAbove(position);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissions, tick);
        assertGt(deferredEmissions, 0);

        // And: A position is staked above the current tick, earning nothing of its own.
        uint256 assetId = _stakeIdlePositionAbove(position);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: They receive nothing, the deferred emissions went to the recipient.
        assertEq(rewards, 0);
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), 0);
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Root_DeferredRewardsGoToRecipient(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A gauge on the root chain deferred the emissions of a burned position, over the redeem floor.
        _stageRoot();
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        position = _givenPositionWithRoomAbove(position);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissions, tick);
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A position is staked above the current tick, earning nothing of its own.
        uint256 assetId = _stakeIdlePositionAbove(position);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: They receive nothing, the deferred emissions were redeemed for the Token to the recipient.
        assertEq(rewards, 0);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), 0);
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Root_DeferredRewardsBelowMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A gauge on the root chain deferred the emissions of a burned position, below the redeem floor.
        _stageRoot();
        emissions = bound(emissions, 2, MIN_REDEEM_AMOUNT - 1);
        position = _givenPositionWithRoomAbove(position);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissions, tick);
        assertGt(deferredEmissions, 0);
        assertLt(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A position is staked above the current tick, earning nothing of its own.
        uint256 assetId = _stakeIdlePositionAbove(position);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: Nothing is delivered, the gauge cleared its deferred emissions but the root handler holds it pending.
        assertEq(rewards, 0);
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), 0);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(receiptToken).balanceOf(emissionsHandler), deferredEmissions);
    }

    function testFuzz_Success_claimReward_Leaf_DeferredRewardsAndOwnReward(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsBurned,
        uint256 emissionsStaked,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: The gauge deferred the emissions of a burned position, over the wei rounding can take.
        emissionsBurned = bound(emissionsBurned, 2, MAX_BASE_RATE);
        position = _givenPositionStakedTwice(position);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissionsBurned, tick);
        assertGt(deferredEmissions, 0);

        // And: A second position is staked over the same range and accrues emissions of its own.
        uint256 assetId = _stakePosition(position);
        emissionsStaked = bound(emissionsStaked, 2, MAX_BASE_RATE);
        addEmissionsToGauge(address(gauge), emissionsStaked);
        vm.warp(block.timestamp + 1);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGt(rewardsExpected, 0);

        // When: The liquidity provider claims the reward.
        // Then: The RewardPaid event reports its own claim, not the swept deferred emissions.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, rewardToken, uint128(rewardsExpected));
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // And: Only its own claim is returned and paid out.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(rewardToken).balanceOf(users.liquidityProvider), rewardsExpected);

        // And: The swept deferred emissions went to the recipient.
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Root_DeferredRewardsAndOwnReward(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsBurned,
        uint256 emissionsStaked,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A gauge on the root chain deferred the emissions of a burned position, over the redeem floor.
        _stageRoot();
        emissionsBurned = bound(emissionsBurned, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        position = _givenPositionStakedTwice(position);
        uint256 deferredEmissions = _stakeAndDeferEmissions(position, emissionsBurned, tick);
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A second position is staked over the same range, accruing over the floor of its own.
        uint256 assetId = _stakePosition(position);
        emissionsStaked = bound(emissionsStaked, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        addEmissionsToGauge(address(gauge), emissionsStaked);
        vm.warp(block.timestamp + 1);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGe(rewardsExpected, MIN_REDEEM_AMOUNT);

        // When: The liquidity provider claims the reward.
        // Then: The RewardPaid event reports its own claim in the Token, not the swept deferred emissions.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, rootToken, uint128(rewardsExpected));
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // And: Only its own claim is returned and paid out.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), rewardsExpected);

        // And: The swept deferred emissions was redeemed for the Token to the recipient.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Root_ExcludesDeferredRewards(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsBurned,
        uint256 emissionsStaked,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

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
        uint256 ownReward = gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId))
            - gauge.deferredEmissions(address(stakedMetadex03CLAM));
        assertGt(ownReward, 0);
        assertLt(ownReward, MIN_REDEEM_AMOUNT);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: Nothing is paid out, the redeem floor is measured against the own claim alone.
        assertEq(rewards, 0);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), 0);
        assertEq(ERC20(receiptToken).balanceOf(emissionsHandler), ownReward);

        // And: The swept deferred emissions cleared the floor on its own and was redeemed to the recipient.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Leaf_DonationNotPaidToOwner(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        uint256 donation,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A position staked on a leaf chain, with emissions accrued to its gauge.
        emissions = bound(emissions, 1, MAX_BASE_RATE / 2);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256 earned = gauge.earned(address(stakedMetadex03CLAM), assetIds);

        // And: Reward tokens reached the Asset Module outside a claim.
        donation = bound(donation, 1, type(uint128).max - earned);
        deal(rewardToken, address(stakedMetadex03CLAM), donation);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: The claim pays out only the emissions of the position.
        assertEq(rewards, earned);
        assertEq(ERC20(rewardToken).balanceOf(users.liquidityProvider), earned);

        // And: What reached the Asset Module outside a claim stays claimable for the recipient.
        assertEq(stakedMetadex03CLAM.claimableSurplus(), donation);
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), donation);
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Root_DonationNotPaidToOwner(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        uint256 donation,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A position staked on the root chain, with emissions clearing the redeem floor.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT, MAX_BASE_RATE / 2);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256 earned = gauge.earned(address(stakedMetadex03CLAM), assetIds);
        vm.assume(earned >= MIN_REDEEM_AMOUNT);

        // And: Reward tokens reached the Asset Module outside a claim.
        donation = bound(donation, 1, type(uint128).max - earned);
        deal(rootToken, address(stakedMetadex03CLAM), donation);

        // When: The liquidity provider claims the reward.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: The claim pays out only the emissions of the position.
        assertEq(rewards, earned);

        // And: What reached the Asset Module outside a claim stays claimable for the recipient.
        assertEq(stakedMetadex03CLAM.claimableSurplus(), donation);
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), donation);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_claimReward_Root_HeldReleasedByLaterClaim(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        int24 tick,
        address ownerSecond,
        address recipient
    ) public canReceiveERC721(ownerSecond) {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A sub-floor claim on the root chain left the reward with the emissions handler.
        position = _givenPositionStakedTwice(position);
        emissionsFirst = bound(emissionsFirst, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 held = _initRootHeldRewards(position, emissionsFirst, tick);
        vm.assume(held > 0);

        // And: A second owner staked a position over the same range in the same gauge.
        _givenValidSecondOwner(ownerSecond);
        uint256 assetId = _stakePositionAs(position, ownerSecond);

        // And: Fresh emissions bring the reward of that position over the redeem floor.
        emissionsSecond = bound(emissionsSecond, MIN_REDEEM_AMOUNT, MAX_BASE_RATE - MIN_REDEEM_AMOUNT);
        addEmissionsToGauge(address(gauge), emissionsSecond);
        vm.warp(block.timestamp + 1);
        uint256 ownReward = gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId))
            - gauge.deferredEmissions(address(stakedMetadex03CLAM));
        vm.assume(ownReward >= MIN_REDEEM_AMOUNT);

        // When: The second owner claims the reward.
        vm.prank(ownerSecond);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: The second owner is paid its own reward alone.
        assertEq(rewards, ownReward);
        assertEq(ERC20(rootToken).balanceOf(ownerSecond), ownReward);

        // And: The handler's hold is booked and a claim pays it to the recipient.
        assertEq(stakedMetadex03CLAM.claimableSurplus(), held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03CLAM)), 0);
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), held);
    }

    function testFuzz_Success_claimReward_Root_HeldReleasedByClaimOnAnotherGauge(
        StakedSlipstreamAM.PositionState memory position,
        StakedSlipstreamAM.PositionState memory positionOther,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        int24 tick,
        int24 tickOther,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A sub-floor claim on the root chain left the reward with the emissions handler.
        emissionsFirst = bound(emissionsFirst, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 held = _initRootHeldRewards(position, emissionsFirst, tick);
        vm.assume(held > 0);

        // And: A second gauge holds a position whose reward clears the redeem floor.
        emissionsSecond = bound(emissionsSecond, MIN_REDEEM_AMOUNT, MAX_BASE_RATE - MIN_REDEEM_AMOUNT);
        uint256 assetId = _initStakedPositionWithEarned(positionOther, emissionsSecond, tickOther);
        uint256 ownReward = gauge.earned(address(stakedMetadex03CLAM), stakedMetadex03CLAM.asSingleton(assetId))
            - gauge.deferredEmissions(address(stakedMetadex03CLAM));
        vm.assume(ownReward >= MIN_REDEEM_AMOUNT);

        // When: The owner claims the reward on the second gauge.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: The owner is paid its own reward alone.
        assertEq(rewards, ownReward);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), ownReward);

        // And: The hold of the first gauge is booked and a claim pays it to the recipient.
        assertEq(stakedMetadex03CLAM.claimableSurplus(), held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03CLAM)), 0);
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), held);
    }

    function testFuzz_Success_claimReward_Root_HeldStaysHeld(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        int24 tick,
        address ownerSecond,
        address recipient
    ) public canReceiveERC721(ownerSecond) {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A sub-floor claim on the root chain left the reward with the emissions handler.
        position = _givenPositionStakedTwice(position);
        emissionsFirst = bound(emissionsFirst, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 held = _initRootHeldRewards(position, emissionsFirst, tick);
        vm.assume(held > 0);

        // And: A second owner staked a position over the same range in the same gauge.
        _givenValidSecondOwner(ownerSecond);
        uint256 assetId = _stakePositionAs(position, ownerSecond);

        // And: Fresh emissions keep the reward of that position below the redeem floor.
        emissionsSecond = bound(emissionsSecond, 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(gauge), emissionsSecond);
        vm.warp(block.timestamp + 1);
        uint256[] memory assetIds = new uint256[](1);
        assetIds[0] = assetId;
        uint256 live = gauge.earned(address(stakedMetadex03CLAM), assetIds);
        vm.assume(live > 0);
        vm.assume(held + live < MIN_REDEEM_AMOUNT);

        // When: The second owner claims the reward.
        vm.prank(ownerSecond);
        uint256 rewards = stakedMetadex03CLAM.claimReward(assetId);

        // Then: Nobody is paid, nothing is booked, the handler holds both legs.
        assertEq(rewards, 0);
        assertEq(ERC20(rootToken).balanceOf(ownerSecond), 0);
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), 0);
        assertEq(pendingRedeemsOf(address(stakedMetadex03CLAM)), held + live);
    }
}
