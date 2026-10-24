/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ERC721 } from "../../../../lib/solmate/src/tokens/ERC721.sol";
import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { ILeafVoter } from "../../../utils/fixtures/metadex03/interfaces/ILeafVoter.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "burn" of contract "StakedMetadex03CLAM".
 */
// forge-lint: disable-next-item(reentrancy-no-eth)
contract Burn_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
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
    function testFuzz_Revert_burn_NonExistingId(uint256 assetId, address sender) public {
        // Given: The asset id is not staked, so its owner reads as the zero address.

        // And: The sender is not the zero address, which can never be a caller.
        vm.assume(sender != address(0));

        // When: The sender burns the position.
        // Then: It reverts.
        vm.prank(sender);
        vm.expectRevert(StakedSlipstreamAM.NotOwner.selector);
        stakedMetadex03CLAM.burn(assetId);
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
        stakedMetadex03CLAM.burn(assetId);
    }

    function testFuzz_Revert_burn_GaugeTapeGasLimit(
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

        // When: The liquidity provider burns the position.
        // Then: It reverts.
        vm.prank(users.liquidityProvider);
        vm.expectRevert(bytes("GL"));
        stakedMetadex03CLAM.burn{ gas: 10_000_000 }(assetId);
    }

    function testFuzz_Success_burn_Leaf_NonZeroReward(
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

        // When: The liquidity provider burns the position.
        // Then: The Transfer and the RewardPaid events are emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        emit ERC721.Transfer(users.liquidityProvider, address(0), assetId);
        vm.expectEmit(address(stakedMetadex03CLAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, receiptToken, uint128(rewardsExpected));
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // And: The reward is returned and paid to the owner.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), rewardsExpected);

        // And: The position is transferred back to the owner.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);

        // And: Nothing is stuck in the Asset Module, staked liquidity accrues no position fees.
        assertEq(token0.balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(token1.balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_burn_Root_NonZeroReward(
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

        // When: The liquidity provider burns the position.
        // Then: The Transfer and the RewardPaid events are emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        emit ERC721.Transfer(users.liquidityProvider, address(0), assetId);
        vm.expectEmit(address(stakedMetadex03CLAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, rootToken, uint128(rewardsExpected));
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // And: The reward is returned and paid to the owner in the Token, not in the ReceiptToken.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), rewardsExpected);

        // And: The position is transferred back to the owner.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);

        // And: Neither side of the redeem is stuck in the Asset Module.
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(receiptToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_burn_Root_AboveMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, whose reward clears the redeem floor.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGe(rewardsExpected, MIN_REDEEM_AMOUNT);

        // When: The liquidity provider burns the position.
        // Then: The RewardPaid event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        // forge-lint: disable-next-line(unsafe-typecast)
        emit StakedSlipstreamAM.RewardPaid(assetId, rootToken, uint128(rewardsExpected));
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // And: The ReceiptToken was redeemed for the Token, which the owner received with its position.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), rewardsExpected);
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_burn_Leaf_ZeroReward(StakedSlipstreamAM.PositionState memory position, int24 tick)
        public
    {
        // Given: A staked position of the liquidity provider, on a gauge that accrued nothing.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);
        position = givenValidPosition(position, 1);
        uint256 assetId = _stakePosition(position);

        // When: The liquidity provider burns the position.
        // Then: The Transfer event is emitted.
        vm.prank(users.liquidityProvider);
        vm.expectEmit(address(stakedMetadex03CLAM));
        emit ERC721.Transfer(users.liquidityProvider, address(0), assetId);
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // And: No reward is returned.
        assertEq(rewards, 0);

        // And: The position is transferred back to the owner.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_burn_Root_BelowMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, whose reward stays below the redeem floor.
        emissions = bound(emissions, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // Then: The position is returned but the root handler holds the sub floor reward pending.
        assertEq(rewards, 0);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), 0);
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);

        // And: The gauge deferred nothing, the mint itself did not revert.
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_burn_Leaf_ExcludesDeferredRewards(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsBurned,
        uint256 emissionsStaked,
        int24 tick
    ) public {
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

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // Then: Only its own reward is returned and paid to the owner.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), rewardsExpected);

        // And: The deferred rewards stay with the gauge, an unstake does not sweep them.
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), deferredEmissions);
    }

    function testFuzz_Success_burn_Root_ExcludesDeferredRewards(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissionsBurned,
        uint256 emissionsStaked,
        uint256 emissionsFinal,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A gauge on the root chain deferred the emissions of a burned position, over the redeem floor.
        _stageRoot();
        emissionsBurned = bound(emissionsBurned, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE / 4);
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

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // Then: Nothing is delivered, the redeem floor is measured against the own claim alone.
        assertEq(rewards, 0);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), 0);

        // And: The deferred rewards stay with the gauge, an unstake does not sweep them.
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), deferredEmissions);
        uint256 held = pendingRedeemsOf(address(stakedMetadex03CLAM));
        assertEq(held, ownReward);

        // And: The position is staked again and accrues over the redeem floor.
        vm.startPrank(users.liquidityProvider);
        metadex03PositionManager.approve(address(stakedMetadex03CLAM), assetId);
        stakedMetadex03CLAM.mint(assetId);
        vm.stopPrank();
        emissionsFinal = bound(emissionsFinal, MIN_REDEEM_AMOUNT, MAX_BASE_RATE / 2);
        addEmissionsToGauge(address(gauge), emissionsFinal);
        vm.warp(block.timestamp + 1);
        uint256 nextReward = stakedMetadex03CLAM.rewardOf(assetId);
        vm.assume(nextReward >= MIN_REDEEM_AMOUNT);

        // When: Its owner claims the reward.
        vm.prank(users.liquidityProvider);
        assertEq(stakedMetadex03CLAM.claimReward(assetId), nextReward);

        // Then: The owner is paid its own reward alone.
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), nextReward);

        // And: The deferred emissions reached the recipient and the handler's hold is booked.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), deferredEmissions);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03CLAM)), 0);
        vm.prank(surplusRecipient);
        stakedMetadex03CLAM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), deferredEmissions + held);
    }

    function testFuzz_Success_burn_Root_HeldReleasedByLaterClaim(
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

        // When: The second owner burns the position.
        vm.prank(ownerSecond);
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

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

    function testFuzz_Success_burn_Root_HeldReleasedByClaimOnAnotherGauge(
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

        // When: The owner burns the position on the second gauge.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

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

    function testFuzz_Success_burn_Leaf_ChainSuspended_NonZeroEarned(
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

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.burn(assetId);

        // Then: The position is transferred back to the owner, the gauge defers what it could not mint.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_burn_Leaf_ChainResumed(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position whose emissions exceed the wei its share can round away.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGt(rewardsExpected, 0);

        // And: The chain was suspended, so a claim reverted while the emissions stayed earned.
        setChainSuspended(true);
        vm.prank(users.liquidityProvider);
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03CLAM.claimReward(assetId);

        // And: The chain is resumed.
        setChainSuspended(false);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // Then: The owner received the earned emissions and the position.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(receiptToken).balanceOf(users.liquidityProvider), rewardsExpected);
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_burn_Root_ChainResumed(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, whose reward clears the redeem floor.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGe(rewardsExpected, MIN_REDEEM_AMOUNT);

        // And: The chain was suspended, so a claim reverted while the emissions stayed earned.
        setChainSuspended(true);
        vm.prank(users.liquidityProvider);
        vm.expectRevert(ILeafVoter.ChainNotActiveOrSunset.selector);
        stakedMetadex03CLAM.claimReward(assetId);

        // And: The chain is resumed.
        setChainSuspended(false);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        uint256 rewards = stakedMetadex03CLAM.burn(assetId);

        // Then: The owner received the earned emissions in the Token, and the position.
        assertEq(rewards, rewardsExpected);
        assertEq(ERC20(rootToken).balanceOf(users.liquidityProvider), rewardsExpected);
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }
}
