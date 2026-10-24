/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "_withdrawAndClaim" of contract "StakedMetadex03CLAM".
 */
contract WithdrawAndClaim_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
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

    function testFuzz_Success_withdrawAndClaim_Leaf_NonZeroReward(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position whose emissions exceed the wei its share can round away.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGt(rewardsExpected, 0);

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The Asset Module holds the Liquidity Position and the claimed emissions.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(stakedMetadex03CLAM));
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), rewardsExpected);
    }

    function testFuzz_Success_withdrawAndClaim_Root_AboveMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, whose reward clears the redeem floor.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGe(rewardsExpected, MIN_REDEEM_AMOUNT);

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The Asset Module holds the Liquidity Position and the redeemed Token.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(stakedMetadex03CLAM));
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), rewardsExpected);
    }

    function testFuzz_Success_withdrawAndClaim_Leaf_ZeroReward(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick
    ) public {
        // Given: A staked position, of which no emissions accrued.
        // forge-lint: disable-next-item(unsafe-typecast)
        tick = int24(bound(tick, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        deployAndAddGauge(tick);
        position = givenValidPosition(position, 1);
        uint256 assetId = _stakePosition(position);

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The Asset Module holds the Liquidity Position and no rewards.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(stakedMetadex03CLAM));
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_withdrawAndClaim_Root_BelowMinRedeemAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position on the root chain, whose reward stays below the redeem floor.
        emissions = bound(emissions, 2, MIN_REDEEM_AMOUNT - 1);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        assertEq(stakedMetadex03CLAM.rewardOf(assetId), 0);

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The Liquidity Position is unstaked but the root handler kept the sub floor reward pending.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(stakedMetadex03CLAM));
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), 0);
    }

    function testFuzz_Success_withdrawAndClaim_Leaf_ExcludesDeferredRewards(
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

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The Asset Module holds the Liquidity Position and only the own emissions of the position.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(stakedMetadex03CLAM));
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), rewardsExpected);

        // And: The deferred rewards stay with the gauge, an unstake does not sweep them.
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), deferredEmissions);
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), 0);
    }

    function testFuzz_Success_withdrawAndClaim_Root_ExcludesDeferredRewards(
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

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The Liquidity Position is unstaked, the sub floor own claim is held pending by the root handler.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(stakedMetadex03CLAM));
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(receiptToken).balanceOf(emissionsHandler), ownReward);

        // And: The deferred rewards stay with the gauge, an unstake does not sweep them.
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), deferredEmissions);
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), 0);
    }

    function testFuzz_Success_withdrawAndClaim_Leaf_ChainSuspended(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A staked position whose emissions exceed the wei its share can round away.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGt(rewardsExpected, 0);

        // And: The chain can no longer mint.
        setChainSuspended(true);

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The Liquidity Position is unstaked but the emissions are deferred, not swept.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(stakedMetadex03CLAM));
        assertEq(ERC20(rewardToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), rewardsExpected);
        assertEq(ERC20(rewardToken).balanceOf(surplusRecipient), 0);
    }

    function testFuzz_Success_withdrawAndClaim_Root_ChainSuspended(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick,
        address recipient
    ) public {
        // Given: A recipient is set.
        _givenSurplusRecipient(recipient);

        // Given: A staked position on the root chain, whose reward clears the redeem floor.
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + 1, MAX_BASE_RATE);
        uint256 assetId = _initRootPositionWithEarned(position, emissions, tick);
        uint256 rewardsExpected = stakedMetadex03CLAM.rewardOf(assetId);
        assertGe(rewardsExpected, MIN_REDEEM_AMOUNT);

        // And: The chain can no longer mint.
        setChainSuspended(true);

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The Liquidity Position is unstaked but the emissions are deferred by the gauge, not redeemed.
        assertEq(metadex03PositionManager.ownerOf(assetId), address(stakedMetadex03CLAM));
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), 0);
        assertEq(gauge.deferredEmissions(address(stakedMetadex03CLAM)), rewardsExpected);
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), 0);

        // And: The root handler was never reached, nothing is pending there.
        assertEq(ERC20(receiptToken).balanceOf(emissionsHandler), 0);
    }

    function testFuzz_Success_withdrawAndClaim_Root_HeldReleasedByLaterClaim(
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

        // When: Calling _withdrawAndClaim().
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The handler's hold is released, and the hook leaves the delivery of the position behind as well.
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), ownReward + held);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), ownReward + held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), 0);
    }

    function testFuzz_Success_withdrawAndClaim_Root_HeldReleasedByClaimOnAnotherGauge(
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

        // When: Calling _withdrawAndClaim() on the second gauge.
        stakedMetadex03CLAM.withdrawAndClaim(address(gauge), assetId);

        // Then: The hold of the first gauge is released, and the hook leaves the delivery of the position behind as well.
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03CLAM)), ownReward + held);
        assertEq(stakedMetadex03CLAM.claimableSurplus(), ownReward + held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03CLAM)), 0);
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), 0);
    }
}
