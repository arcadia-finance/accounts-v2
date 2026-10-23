/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { StakedMetadex03AM_Fuzz_Test } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getSurplus" of contract "StakedMetadex03AM".
 */
// forge-lint: disable-next-item(reentrancy-no-eth)
contract GetSurplus_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getSurplus_Leaf_NoDeferredRewards(uint256 lpBalance, uint256 emissions, address recipient)
        public
    {
        // Given: A staked position without deferred emissions, and a recipient.
        emissions = bound(emissions, 1, type(uint128).max);
        (, uint256 positionId) = _stakeInGauge(lpBalance);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        _givenSurplusRecipient(recipient);

        // When: The Asset Module claims for the position.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: Nothing is booked, the emissions stay for the position.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(ERC20(receiptToken).balanceOf(recipient), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Root_NoDeferredRewards(uint256 lpBalance, uint256 emissions, address recipient)
        public
    {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A staked position without deferred emissions, earning above the redeem floor.
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);
        emissions = bound(emissions, MIN_REDEEM_AMOUNT + staked / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));

        // And: A recipient is set.
        _givenSurplusRecipient(recipient);

        // When: The Asset Module claims for the position.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: Nothing is booked, the redeemed Token stays for the position.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(ERC20(rootToken).balanceOf(recipient), 0);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), earned);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Leaf_StillDeferred(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The gauge deferred the emissions of a position, and a recipient is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        _givenSurplusRecipient(recipient);

        // And: The chain is suspended again, so the gauge cannot deliver them.
        setChainSuspended(true);

        // When: The Asset Module interacts with the gauge for the position.
        stakedMetadex03AM.withdrawAndClaim(positionId, address(metadex03Pool), 1);

        // Then: Nothing is booked, the gauge still holds the deferred emissions of the staker.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(ERC20(receiptToken).balanceOf(recipient), 0);
        assertGe(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), deferredEmissions);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Root_StillDeferred(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: The gauge deferred emissions, of any size the root Minter can mint, and a recipient is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        _givenSurplusRecipient(recipient);

        // And: The chain is suspended again, so the gauge cannot deliver them.
        setChainSuspended(true);

        // When: The Asset Module interacts with the gauge for the position.
        stakedMetadex03AM.withdrawAndClaim(positionId, address(metadex03Pool), 1);

        // Then: Nothing is booked, the gauge still holds the deferred emissions of the staker.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(ERC20(rootToken).balanceOf(recipient), 0);
        assertGe(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), deferredEmissions);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Leaf_Delivered(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The gauge deferred the emissions of a position, and a recipient is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        _givenSurplusRecipient(recipient);

        // When: The Asset Module claims for the position, which delivers the deferred emissions.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The deferred emissions are booked for the recipient, no position is credited for them.
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions);
        assertEq(ERC20(receiptToken).balanceOf(recipient), 0);

        // And: A claim pays the recipient exactly that.
        assertEq(stakedMetadex03AM.claimableSurplus(), deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(receiptToken).balanceOf(recipient), deferredEmissions);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Root_Delivered(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: The gauge deferred emissions at or above the redeem floor, within what the root Minter can mint.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max));
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A recipient is set.
        _givenSurplusRecipient(recipient);

        // When: The Asset Module claims, which delivers and redeems the deferred emissions.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The deferred emissions are booked for the recipient, nothing stays with the handler.
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions);
        assertEq(ERC20(rootToken).balanceOf(recipient), 0);

        // And: A claim pays the recipient exactly that.
        assertEq(stakedMetadex03AM.claimableSurplus(), deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(recipient), deferredEmissions);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), 0);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Leaf_Delivered_StakePath(
        uint128 amount,
        uint128 amountSecond,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The gauge deferred the emissions of a position, and a recipient is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max - 1));
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        _givenSurplusRecipient(recipient);

        // And: An extra amount that keeps the total in a uint128.
        // forge-lint: disable-next-item(unsafe-typecast)
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));

        // When: The position increases its liquidity, which first claims the deferred emissions.
        _increasePosition(users.accountOwner, positionId, amountSecond);

        // Then: The deferred emissions are booked for the recipient.
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions);
        assertEq(ERC20(receiptToken).balanceOf(recipient), 0);
        (,,, uint128 lastRewardPosition) = stakedMetadex03AM.positionState(positionId);
        assertEq(lastRewardPosition, 0);

        // And: A claim pays the recipient exactly that.
        assertEq(stakedMetadex03AM.claimableSurplus(), deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(receiptToken).balanceOf(recipient), deferredEmissions);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Root_Delivered_StakePath(
        uint128 amount,
        uint128 amountSecond,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: The gauge deferred emissions at or above the redeem floor, and a recipient is set.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, type(uint128).max - 1));
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);
        _givenSurplusRecipient(recipient);

        // And: An extra amount that keeps the total in a uint128.
        // forge-lint: disable-next-item(unsafe-typecast)
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max - amount));

        // When: The position increases its liquidity, which first claims the deferred emissions.
        _increasePosition(users.accountOwner, positionId, amountSecond);

        // Then: The deferred emissions are booked for the recipient.
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions);
        assertEq(ERC20(rootToken).balanceOf(recipient), 0);
        (,,, uint128 lastRewardPosition) = stakedMetadex03AM.positionState(positionId);
        assertEq(lastRewardPosition, 0);

        // And: A claim pays the recipient exactly that.
        assertEq(stakedMetadex03AM.claimableSurplus(), deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(recipient), deferredEmissions);
        assertEq(metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId)), 0);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Root_DeferredBelowFloor(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake small enough that a sub-floor amount still clears the gauge's per-1e18 flooring.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, (MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI) * PRECISION));

        // And: The gauge deferred emissions that stays below the redeem floor.
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        assertLt(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A recipient is set.
        _givenSurplusRecipient(recipient);

        // When: The Asset Module claims, which clears the deferred emissions but redeems nothing.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The root handler holds the sub-floor amount, so nothing is booked.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(ERC20(rootToken).balanceOf(recipient), 0);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), 0);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), deferredEmissions);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function testFuzz_Success_getSurplus_Root_DeferredBelowFloor_PriorBalance(
        uint128 amountPrior,
        uint256 emissionsPrior,
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: The Asset Module holds the claimed rewards of a position on the stable gauge.
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), true);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(stablePool));
        address stableGauge = address(createGaugeMetadex03(address(stablePool)));
        stakedMetadex03AM.addAsset(stableGauge);
        (uint256 stakedPrior, uint256 positionIdPrior) = _dealAndStake(address(stablePool), amountPrior);
        emissionsPrior = bound(
            emissionsPrior,
            MIN_REDEEM_AMOUNT + stakedPrior / PRECISION + GAUGE_ROUNDING_WEI,
            MAX_BASE_RATE - MIN_REDEEM_AMOUNT
        );
        addEmissionsToGauge(stableGauge, emissionsPrior);
        stakedMetadex03AM.claimReward(positionIdPrior, address(stablePool));
        uint256 priorBalance = ERC20(rootToken).balanceOf(address(stakedMetadex03AM));
        assertGt(priorBalance, 0);

        // And: A stake small enough that a sub-floor amount still clears the gauge's per-1e18 flooring.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, (MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI) * PRECISION));

        // And: The volatile gauge deferred emissions that stays below the redeem floor.
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissions, withdrawAmount);
        assertLt(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A recipient is set.
        _givenSurplusRecipient(recipient);

        // When: The Asset Module claims, which clears the deferred emissions but redeems nothing.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The other position's rewards are not booked, the handler keeps its hold.
        assertEq(stakedMetadex03AM.bookedSurplus(), 0);
        assertEq(ERC20(rootToken).balanceOf(recipient), 0);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), priorBalance);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), deferredEmissions);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function testFuzz_Success_getSurplus_Root_HeldReleased(
        uint128 amount,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake small enough that a sub-floor amount still clears the gauge's per-1e18 flooring.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, (MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI) * PRECISION));

        // And: The gauge deferred emissions that stays below the redeem floor.
        emissionsFirst = bound(emissionsFirst, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissionsFirst, withdrawAmount);
        assertLt(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A recipient is set.
        _givenSurplusRecipient(recipient);

        // And: A claim cleared the deferred emissions, which the root handler holds below its floor.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), deferredEmissions);

        // And: Fresh emissions push the handler's running total over the floor, within what the root Minter can mint.
        emissionsSecond = bound(
            emissionsSecond,
            MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI,
            MAX_BASE_RATE - emissionsFirst
        );
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);

        // When: The Asset Module claims again, releasing the handler's hold with the fresh leg.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: The handler's hold is booked for the recipient, the Asset Module holds the fresh leg.
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions);
        assertEq(ERC20(rootToken).balanceOf(recipient), 0);

        // And: A claim pays the recipient exactly that.
        assertEq(stakedMetadex03AM.claimableSurplus(), deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(recipient), deferredEmissions);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function testFuzz_Success_getSurplus_Root_HeldReleasedByOtherGauge(
        uint128 amount,
        uint128 amountOther,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake small enough that a sub-floor amount still clears the gauge's per-1e18 flooring.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, (MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI) * PRECISION));

        // And: The volatile gauge deferred emissions that stays below the redeem floor.
        emissionsFirst = bound(emissionsFirst, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId, uint256 deferredEmissions) =
            _initPositionWithDeferredRewards(amount, emissionsFirst, withdrawAmount);
        assertLt(deferredEmissions, MIN_REDEEM_AMOUNT);

        // And: A recipient is set.
        _givenSurplusRecipient(recipient);

        // And: A claim cleared the deferred emissions, which the root handler holds below its floor.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), deferredEmissions);

        // And: The stable pool of the same pair has its own gauge, with a position of its own.
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), true);
        vm.prank(users.owner);
        metadex03PoolAM.addAsset(address(stablePool));
        address stableGauge = address(createGaugeMetadex03(address(stablePool)));
        stakedMetadex03AM.addAsset(stableGauge);
        (uint256 stakedOther, uint256 positionIdOther) = _dealAndStake(address(stablePool), amountOther);

        // And: Fresh emissions on the stable gauge push the handler's running total over the floor.
        emissionsSecond = bound(
            emissionsSecond,
            MIN_REDEEM_AMOUNT + stakedOther / PRECISION + GAUGE_ROUNDING_WEI,
            MAX_BASE_RATE - emissionsFirst
        );
        addEmissionsToGauge(stableGauge, emissionsSecond);

        // When: The Asset Module claims for the stable position.
        stakedMetadex03AM.claimReward(positionIdOther, address(stablePool));

        // Then: The handler's hold is booked for the recipient, the Asset Module holds the stable leg.
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions);
        assertEq(ERC20(rootToken).balanceOf(recipient), 0);

        // And: A claim pays the recipient exactly that.
        assertEq(stakedMetadex03AM.claimableSurplus(), deferredEmissions);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(recipient), deferredEmissions);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Root_HeldReleasedByOtherPosition(
        uint256 lpBalance,
        uint256 lpBalanceOther,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake for which the gauge's flooring rounds away at most one wei.
        (, uint256 positionId) = _stakeInGauge(bound(lpBalance, 1, PRECISION));

        // And: A claim left the sub-floor accrual of the position with the handler, held in full.
        emissionsFirst = bound(emissionsFirst, MIN_REDEEM_AMOUNT / 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissionsFirst);
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));
        assertGt(held, 0);

        // And: A recipient is set.
        _givenSurplusRecipient(recipient);

        // And: A second position in the same gauge, staking at least as much as the first.
        (uint256 stakedOther, uint256 positionIdOther) =
            _dealAndStake(address(metadex03Pool), bound(lpBalanceOther, PRECISION, type(uint128).max));

        // And: Fresh emissions of which the half share of the second position clears the floor.
        emissionsSecond = bound(
            emissionsSecond,
            2 * (MIN_REDEEM_AMOUNT + stakedOther / PRECISION + GAUGE_ROUNDING_WEI),
            MAX_BASE_RATE - emissionsFirst
        );
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);
        uint256 earnedOther = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionIdOther));
        assertGe(earnedOther, MIN_REDEEM_AMOUNT);

        // When: The Asset Module claims for the second position.
        stakedMetadex03AM.claimReward(positionIdOther, address(metadex03Pool));

        // Then: The hold is booked for the recipient, the second position keeps its own accrual.
        assertEq(stakedMetadex03AM.bookedSurplus(), held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), held + earnedOther);

        // And: A claim pays the recipient exactly that.
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(recipient), held);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), earnedOther);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth,unsafe-typecast)
    function testFuzz_Success_getSurplus_Root_DeferredAndHeldReleased(
        uint256 amountHeld,
        uint256 emissionsHeld,
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        address recipient
    ) public {
        // Given: The protocol is staged on the root chain, with a recipient set.
        _stageMetadex03(true);
        _givenSurplusRecipient(recipient);

        // And: A small position whose claim left its sub-floor accrual with the handler.
        _addGauge();
        uint256 positionIdHeld = _mintPosition(users.liquidityProvider, uint128(bound(amountHeld, 1, PRECISION)));
        emissionsHeld = bound(emissionsHeld, MIN_REDEEM_AMOUNT / 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissionsHeld);
        vm.startPrank(users.liquidityProvider);
        stakedMetadex03AM.claimReward(positionIdHeld);
        (, uint128 amountStakedHeld,,) = stakedMetadex03AM.positionState(positionIdHeld);
        stakedMetadex03AM.decreaseLiquidity(positionIdHeld, amountStakedHeld);
        vm.stopPrank();

        // And: A second position whose staker the gauge deferred emissions at the redeem floor.
        amount = uint128(bound(amount, 2, type(uint128).max));
        uint256 positionId = _mintPosition(users.accountOwner, amount);
        emissions =
            bound(emissions, MIN_REDEEM_AMOUNT + uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE / 2);
        addEmissionsToGauge(address(metadex03Gauge), emissions);
        setChainSuspended(true);
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, uint128(bound(withdrawAmount, 1, amount - 1)));
        setChainSuspended(false);

        // And: Both the deferred emissions and the hold of the handler are non-zero.
        uint256 deferredEmissions = metadex03Gauge.deferredEmissions(stakedMetadex03AM.getStaker(positionId));
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));
        assertGe(deferredEmissions, MIN_REDEEM_AMOUNT);
        assertGt(held, 0);

        // When: The second position claims, which releases its deferred emissions and the hold.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionId);

        // Then: Both the deferred emissions and the hold are booked for the recipient.
        assertEq(stakedMetadex03AM.bookedSurplus(), deferredEmissions + held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);
        assertEq(ERC20(rootToken).balanceOf(users.accountOwner), 0);

        // And: A claim pays the recipient exactly that.
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(recipient), deferredEmissions + held);
    }

    /*///////////////////////////////////////////////////////////////
                     RELEASED OUTSIDE A MODULE CLAIM
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_getSurplus_Root_ReleasedByLp(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        GaugeState memory gaugeState
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake small enough that a sub-floor amount still clears the gauge's per-1e18 flooring.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI));

        // And: A claim left the position's deferred emissions with the handler, below its floor.
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId, uint256 deferredEmissions) = _initHeldDeferredRewards(amount, emissions, withdrawAmount);
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), deferredEmissions);

        // And: An unrelated LP stakes in the same gauge and accrues past the redeem floor.
        givenValidGaugeState(gaugeState, metadex03Gauge.balanceOf(staker));
        depositInGauge(address(metadex03Gauge), users.liquidityProvider, gaugeState.stake);
        addEmissionsToGauge(address(metadex03Gauge), gaugeState.emissions);

        // And: That LP claimed their own emissions, naming this contract as the recipient.
        claimEmissionsTo(address(metadex03Gauge), users.liquidityProvider, address(stakedMetadex03AM));
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);
        uint256 released = ERC20(rootToken).balanceOf(address(stakedMetadex03AM));
        assertGe(released, deferredEmissions);

        // And: The root handler redeems what the staker earned only from the redeem floor up.
        uint256 earned = metadex03Gauge.earned(staker);
        uint256 ownReward = earned < MIN_REDEEM_AMOUNT ? 0 : earned;

        // When: The recipient claims the surplus, then the position claims its reward.
        assertEq(stakedMetadex03AM.claimableSurplus(), released);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionId);

        // Then: The owner is paid the redeemed emissions of its staker alone.
        assertEq(ERC20(rootToken).balanceOf(users.accountOwner), ownReward);

        // And: Everything that reached this contract outside a claim went to the recipient.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), released);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Root_ReleasedByLp_DecreaseLiquidity(
        uint128 amount,
        uint256 emissions,
        uint256 withdrawAmount,
        GaugeState memory gaugeState
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake small enough that a sub-floor amount still clears the gauge's per-1e18 flooring.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 4, MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI));

        // And: A claim left the position's deferred emissions with the handler, below its floor.
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId,) = _initHeldDeferredRewards(amount, emissions, withdrawAmount);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: An unrelated LP released the handler by naming this contract as their claim recipient.
        givenValidGaugeState(gaugeState, metadex03Gauge.balanceOf(staker));
        depositInGauge(address(metadex03Gauge), users.liquidityProvider, gaugeState.stake);
        addEmissionsToGauge(address(metadex03Gauge), gaugeState.emissions);
        claimEmissionsTo(address(metadex03Gauge), users.liquidityProvider, address(stakedMetadex03AM));
        uint256 released = ERC20(rootToken).balanceOf(address(stakedMetadex03AM));

        // And: The root handler redeems what the staker earned only from the redeem floor up.
        uint256 earned = metadex03Gauge.earned(staker);
        uint256 ownReward = earned < MIN_REDEEM_AMOUNT ? 0 : earned;

        // When: The recipient claims the surplus, then the position is decreased.
        assertEq(stakedMetadex03AM.claimableSurplus(), released);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        vm.prank(users.accountOwner);
        stakedMetadex03AM.decreaseLiquidity(positionId, 1);

        // Then: The owner is paid the redeemed emissions of its staker alone.
        assertEq(ERC20(rootToken).balanceOf(users.accountOwner), ownReward);

        // And: Everything that reached this contract outside a claim went to the recipient.
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), released);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function testFuzz_Success_getSurplus_Root_ToppedUpBelowFloorByLp(
        uint128 amount,
        uint256 emissions,
        uint256 emissionsTopUp,
        uint256 emissionsFinal,
        uint256 withdrawAmount
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake small enough that a sub-floor amount still clears the gauge's per-1e18 flooring.
        // forge-lint: disable-next-item(unsafe-typecast)
        amount = uint128(bound(amount, 2, MIN_REDEEM_AMOUNT - 1 - GAUGE_ROUNDING_WEI));

        // And: A claim left the position's deferred emissions with the handler, below its floor.
        emissions = bound(emissions, uint256(amount) / PRECISION + GAUGE_ROUNDING_WEI, MIN_REDEEM_AMOUNT - 1);
        (uint256 positionId, uint256 deferredEmissions) = _initHeldDeferredRewards(amount, emissions, withdrawAmount);
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), deferredEmissions);

        // And: An unrelated LP staked the same amount as the staker in the same gauge.
        depositInGauge(address(metadex03Gauge), users.liquidityProvider, metadex03Gauge.balanceOf(staker));

        // And: That LP topped up the handler's hold without reaching the redeem floor.
        emissionsTopUp =
            bound(emissionsTopUp, GAUGE_ROUNDING_WEI, GAUGE_ROUNDING_WEI + MIN_REDEEM_AMOUNT - 1 - deferredEmissions);
        addEmissionsToGauge(address(metadex03Gauge), emissionsTopUp);
        claimEmissionsTo(address(metadex03Gauge), users.liquidityProvider, address(stakedMetadex03AM));
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));
        vm.assume(held > deferredEmissions);
        vm.assume(held < MIN_REDEEM_AMOUNT);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), 0);

        // And: Fresh emissions bring the live reward of the staker over the redeem floor.
        emissionsFinal = bound(emissionsFinal, MIN_REDEEM_AMOUNT, MAX_BASE_RATE - MIN_REDEEM_AMOUNT);
        addEmissionsToGauge(address(metadex03Gauge), emissionsFinal);
        uint256 ownReward = metadex03Gauge.earned(staker);
        vm.assume(ownReward >= MIN_REDEEM_AMOUNT);

        // When: The position claims, which releases the handler's hold with its live reward.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionId);

        // Then: The owner is paid the earned emissions of its staker alone.
        assertEq(ERC20(rootToken).balanceOf(users.accountOwner), ownReward);

        // And: The handler's hold, the top-up included, is booked and paid to the recipient.
        assertEq(stakedMetadex03AM.bookedSurplus(), held);
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), held);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }

    function testFuzz_Success_getSurplus_Root_SubFloorAccrualBooked(
        uint256 lpBalance,
        uint256 emissionsFirst,
        uint256 emissionsSecond
    ) public {
        // Given: The protocol is staged on the root chain.
        _stageMetadex03(true);

        // And: A stake for which the gauge's flooring rounds away at most one wei.
        (uint256 staked, uint256 positionId) = _stakeInGauge(bound(lpBalance, 1, PRECISION));
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: An accrual below the redeem floor, with no deferred emissions anywhere.
        emissionsFirst = bound(emissionsFirst, MIN_REDEEM_AMOUNT / 2, MIN_REDEEM_AMOUNT - 1);
        addEmissionsToGauge(address(metadex03Gauge), emissionsFirst);
        assertEq(metadex03Gauge.deferredEmissions(staker), 0);

        // And: A claim left it with the handler, which holds it in full.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));
        uint256 held = pendingRedeemsOf(address(stakedMetadex03AM));
        assertGt(held, 0);

        // And: A second accrual that carries the handler's running total over the redeem floor.
        emissionsSecond = bound(
            emissionsSecond, MIN_REDEEM_AMOUNT + staked / PRECISION + GAUGE_ROUNDING_WEI, MAX_BASE_RATE - emissionsFirst
        );
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);
        uint256 earned = metadex03Gauge.earned(staker);

        // When: The Asset Module claims for the position again, releasing what the handler held.
        stakedMetadex03AM.claimReward(positionId, address(metadex03Pool));

        // Then: What the handler held is booked, only the fresh accrual is left for the position.
        assertEq(stakedMetadex03AM.bookedSurplus(), held);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), uint256(held) + earned);
        assertEq(pendingRedeemsOf(address(stakedMetadex03AM)), 0);

        // And: A claim pays the recipient exactly that, the fresh accrual stays.
        vm.prank(surplusRecipient);
        stakedMetadex03AM.claimSurplus();
        assertEq(ERC20(rootToken).balanceOf(surplusRecipient), held);
        assertEq(ERC20(rootToken).balanceOf(address(stakedMetadex03AM)), earned);

        // And: The reward token balance is cached.
        assertEq(
            stakedMetadex03AM.getLastRewardBalance(),
            stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM))
        );
    }
}
