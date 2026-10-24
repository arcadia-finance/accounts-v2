/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { IMetadex03V2GaugeFactory } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2GaugeFactory.sol";
import { IMetadex03V2Pool } from "../../../utils/fixtures/metadex03/interfaces/IMetadex03V2Pool.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "StakeAndClaim" function of contract "StakedMetadex03AM".
 */
contract StakeAndClaim_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_stakeAndClaim_PenaltyWindowOpen(
        uint128 initialStake,
        uint128 extraStake,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 blocksPassed
    ) public {
        // Given: A position staked in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        (, uint256 positionId) = _stakeInGaugeWithPenalty(initialStake, minStakeBlocks, penaltyRate);

        // And: Emissions accrue, within the gauge's uint128 reward share.
        emissions = bound(emissions, 1, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // And: The penalty window of the initial deposit is still open.
        blocksPassed = bound(blocksPassed, 0, minStakeBlocks - 1);
        vm.roll(block.number + blocksPassed);

        // And: A non-zero extra amount sits in the Asset Module.
        vm.assume(extraStake != 0);
        deal(address(metadex03Pool), address(stakedMetadex03AM), extraStake);

        // When: An additional amount is staked for the position.
        // Then: It reverts.
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.stakeAndClaim(positionId, address(metadex03Pool), extraStake);
    }

    function testFuzz_Revert_stakeAndClaim_ArbGauge_PenaltyWindowOpen(
        uint128 initialStake,
        uint128 extraStake,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 arbBlockNumber,
        uint256 blocksPassed
    ) public {
        // Given: Gauges that read the block height from ArbSys.
        metadex03ArbGauges = true;
        _stageMetadex03(false);

        // And: A gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);

        // And: The Arbitrum block number is above block.number.
        arbBlockNumber = bound(arbBlockNumber, vm.getBlockNumber() + 1, type(uint256).max - 2 * minStakeBlocks);
        vm.etch(address(0x64), hex"00");
        vm.mockCall(address(0x64), abi.encodeWithSignature("arbBlockNumber()"), abi.encode(arbBlockNumber));

        // And: A position is staked through its own staker.
        (, uint256 positionId) = _dealAndStake(address(metadex03Pool), initialStake);

        // And: block.number passes the penalty window, the Arbitrum block number does not.
        blocksPassed = bound(blocksPassed, 0, minStakeBlocks - 1);
        vm.mockCall(
            address(0x64), abi.encodeWithSignature("arbBlockNumber()"), abi.encode(arbBlockNumber + blocksPassed)
        );
        vm.roll(arbBlockNumber + minStakeBlocks);

        // And: A non-zero extra amount sits in the Asset Module.
        vm.assume(extraStake != 0);
        deal(address(metadex03Pool), address(stakedMetadex03AM), extraStake);

        // When: An additional amount is staked for the position.
        // Then: It reverts.
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.stakeAndClaim(positionId, address(metadex03Pool), extraStake);
    }

    function testFuzz_Revert_stakeAndClaim_GaugeTapeGasLimit(uint128 stake, address gaugeTape) public {
        // Given: An onboarded gauge.
        _addGauge();

        // And: A gauge tape whose gas limit exceeds the gas left in the call.
        vm.assume(gaugeTape != address(0));
        setGaugeTape(address(metadex03Gauge), gaugeTape, type(uint32).max);

        // And: A non-zero amount sits in the Asset Module.
        vm.assume(stake != 0);
        deal(address(metadex03Pool), address(stakedMetadex03AM), stake);
        uint256 positionId = stakedMetadex03AM.getLastPositionId() + 1;

        // When: The amount is staked for a new position.
        // Then: It reverts.
        vm.expectRevert(IMetadex03V2GaugeFactory.InsufficientGasForCall.selector);
        stakedMetadex03AM.stakeAndClaim{ gas: 10_000_000 }(positionId, address(metadex03Pool), stake);
    }

    function testFuzz_Success_stakeAndClaim(uint256 lpBalance, uint256 emissions) public {
        // Given: A position staked through its own staker.
        (uint256 staked, uint256 positionId) = _stakeInGauge(lpBalance);
        address staker = stakedMetadex03AM.getStaker(positionId);

        // And: Emissions accrue, within the gauge's uint128 reward share.
        emissions = bound(emissions, 1, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // And: Rewards accumulate over three days.
        vm.warp(block.timestamp + 3 days);
        uint256 earned = metadex03Gauge.earned(staker);

        // And: A second LP balance of the same size sits in the Asset Module.
        deal(address(metadex03Pool), address(stakedMetadex03AM), staked);

        // When: An additional amount is staked for the position.
        stakedMetadex03AM.stakeAndClaim(positionId, address(metadex03Pool), staked);

        // Then: The stake of the staker doubled and its pending rewards are claimed.
        assertEq(metadex03Gauge.balanceOf(staker), staked * 2);
        assertEq(metadex03Gauge.balanceOf(address(stakedMetadex03AM)), 0);
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), earned);
    }

    function testFuzz_Success_stakeAndClaim_NewStaker(uint256 lpBalance) public {
        // Given: An onboarded gauge.
        _addGauge();

        // And: A non-zero LP balance sits in the Asset Module, no emissions accrued to the gauge.
        vm.assume(lpBalance != 0);
        deal(address(metadex03Pool), address(stakedMetadex03AM), lpBalance);
        uint256 positionId = stakedMetadex03AM.getLastPositionId() + 1;

        // When: The LP is staked for a new position.
        stakedMetadex03AM.stakeAndClaim(positionId, address(metadex03Pool), lpBalance);

        // Then: The staker of the position is deployed and holds the full stake.
        address staker = stakedMetadex03AM.getStaker(positionId);
        assertGt(staker.code.length, 0);
        assertEq(metadex03Gauge.balanceOf(staker), lpBalance);
        assertEq(metadex03Gauge.balanceOf(address(stakedMetadex03AM)), 0);
        assertEq(metadex03Pool.balanceOf(address(stakedMetadex03AM)), 0);

        // And: The Asset Module can withdraw and claim for the staker.
        assertTrue(metadex03Gauge.isApprovedForAll(staker, address(stakedMetadex03AM)));
        assertTrue(metadex03Gauge.approvedForClaim(staker, address(stakedMetadex03AM)));
    }

    function testFuzz_Success_stakeAndClaim_NewStaker_OtherPenaltyWindowOpen(
        uint128 stakeFirst,
        uint128 stakeSecond,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 blocksPassed
    ) public {
        // Given: A position staked in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        (, uint256 positionIdFirst) = _stakeInGaugeWithPenalty(stakeFirst, minStakeBlocks, penaltyRate);
        address stakerFirst = stakedMetadex03AM.getStaker(positionIdFirst);
        uint256 depositBlockFirst = metadex03Gauge.depositBlock(stakerFirst);

        // And: The penalty window of that position is still open.
        blocksPassed = bound(blocksPassed, 0, minStakeBlocks - 1);
        vm.roll(block.number + blocksPassed);

        // When: An amount is staked for a new position.
        (uint256 stakedSecond, uint256 positionIdSecond) = _dealAndStake(address(metadex03Pool), stakeSecond);

        // Then: The fresh staker holds the stake.
        assertEq(metadex03Gauge.balanceOf(stakedMetadex03AM.getStaker(positionIdSecond)), stakedSecond);

        // And: The penalty window of the first position is left untouched.
        assertEq(metadex03Gauge.depositBlock(stakerFirst), depositBlockFirst);
    }

    function testFuzz_Success_stakeAndClaim_PenaltyActive_ClaimBeforeDeposit(
        uint128 initialStake,
        uint128 extraStake,
        uint256 emissions,
        uint256 minStakeBlocks,
        uint256 penaltyRate
    ) public {
        // Given: A position staked in a gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        (uint256 staked, uint256 positionId) = _stakeInGaugeWithPenalty(initialStake, minStakeBlocks, penaltyRate);

        // And: Emissions accrue, above what the gauge's per-1e18 flooring rounds away.
        emissions = bound(emissions, staked / PRECISION + GAUGE_ROUNDING_WEI, type(uint128).max);
        addEmissionsToGauge(address(metadex03Gauge), emissions);

        // And: The penalty window of the initial deposit has passed.
        vm.roll(block.number + minStakeBlocks);
        uint256 earned = metadex03Gauge.earned(stakedMetadex03AM.getStaker(positionId));
        assertGt(earned, 0);

        // And: A non-zero extra amount sits in the Asset Module.
        vm.assume(extraStake != 0);
        deal(address(metadex03Pool), address(stakedMetadex03AM), extraStake);

        // When: An additional amount is staked for the position.
        stakedMetadex03AM.stakeAndClaim(positionId, address(metadex03Pool), extraStake);

        // Then: The full un-haircut reward is claimed, the claim ran before the deposit reset the window.
        assertEq(stakedMetadex03AM.REWARD_TOKEN().balanceOf(address(stakedMetadex03AM)), earned);
    }

    function testFuzz_Success_stakeAndClaim_ArbGauge_PenaltyWindowClosed(
        uint128 initialStake,
        uint128 extraStake,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 arbBlockNumber,
        uint256 blocksPassed
    ) public {
        // Given: Gauges that read the block height from ArbSys.
        metadex03ArbGauges = true;
        _stageMetadex03(false);

        // And: A gauge whose GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);

        // And: The Arbitrum block number is above block.number.
        arbBlockNumber = bound(arbBlockNumber, vm.getBlockNumber() + 1, type(uint256).max - 2 * minStakeBlocks);
        vm.etch(address(0x64), hex"00");
        vm.mockCall(address(0x64), abi.encodeWithSignature("arbBlockNumber()"), abi.encode(arbBlockNumber));

        // And: A position is staked through its own staker.
        (, uint256 positionId) = _dealAndStake(address(metadex03Pool), initialStake);

        // And: The Arbitrum block number passes the penalty window, block.number does not.
        blocksPassed = bound(blocksPassed, minStakeBlocks, type(uint256).max - arbBlockNumber - minStakeBlocks);
        vm.mockCall(
            address(0x64), abi.encodeWithSignature("arbBlockNumber()"), abi.encode(arbBlockNumber + blocksPassed)
        );

        // And: A non-zero extra amount sits in the Asset Module.
        vm.assume(extraStake != 0);
        deal(address(metadex03Pool), address(stakedMetadex03AM), extraStake);

        // When: An additional amount is staked for the position.
        stakedMetadex03AM.stakeAndClaim(positionId, address(metadex03Pool), extraStake);

        // Then: The deposit went through on the clock of the gauge.
        assertEq(metadex03Gauge.depositBlock(stakedMetadex03AM.getStaker(positionId)), arbBlockNumber + blocksPassed);
    }

    // forge-lint: disable-next-item(reentrancy-no-eth)
    function testFuzz_Success_stakeAndClaim_PenaltyActive_PositionRewardsStayCovered(
        uint128 amountFirst,
        uint128 amountSecond,
        uint128 amountIncrease,
        uint256 emissionsFirst,
        uint256 emissionsSecond,
        uint256 minStakeBlocks,
        uint256 penaltyRate,
        uint256 blocksFirst,
        uint256 blocksSecond
    ) public {
        // Given: Three stakes that together fit the Asset Module's uint128 totalStaked.
        // forge-lint: disable-next-item(unsafe-typecast)
        amountFirst = uint128(bound(amountFirst, 1, type(uint128).max / 3));
        // forge-lint: disable-next-item(unsafe-typecast)
        amountSecond = uint128(bound(amountSecond, 1, type(uint128).max / 3));
        // forge-lint: disable-next-item(unsafe-typecast)
        amountIncrease = uint128(bound(amountIncrease, 1, type(uint128).max / 3));

        // And: Both emission legs fit in the gauge's uint128 reward share.
        emissionsFirst = bound(emissionsFirst, 0, type(uint128).max / 2);
        emissionsSecond = bound(emissionsSecond, 0, type(uint128).max - emissionsFirst);

        // And: A GaugeFactory that may or may not penalise an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 0, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 0, MAX_PIPS);

        // And: Block numbers stay representable when the gauge adds minStakeBlocks to a stored deposit block.
        uint256 headroom = type(uint256).max - vm.getBlockNumber() - 3 * minStakeBlocks;
        blocksFirst = bound(blocksFirst, 0, headroom);
        blocksSecond = bound(blocksSecond, 0, headroom - blocksFirst);

        // And: The gauge is onboarded with that penalty config.
        _addGaugeWithPenalty(minStakeBlocks, penaltyRate);

        // When: A first user mints a first position.
        uint256[] memory positionIds = new uint256[](2);
        positionIds[0] = _mintPosition(users.accountOwner, amountFirst);

        // Then: The AM balance covers all credited position rewards.
        assertSolvent(positionIds);

        // And: Emissions accrue and the penalty window of the first deposit closes.
        addEmissionsToGauge(address(metadex03Gauge), emissionsFirst);
        vm.roll(vm.getBlockNumber() + minStakeBlocks + blocksFirst);

        // When: A second user mints a second position.
        positionIds[1] = _mintPosition(users.liquidityProvider, amountSecond);

        // Then: The AM balance covers all credited position rewards.
        assertSolvent(positionIds);

        // And: More emissions accrue and that penalty window closes as well.
        addEmissionsToGauge(address(metadex03Gauge), emissionsSecond);
        vm.roll(vm.getBlockNumber() + minStakeBlocks + blocksSecond);

        // When: The first user increases liquidity.
        _increasePosition(users.accountOwner, positionIds[0], amountIncrease);

        // Then: The AM balance covers all credited position rewards.
        assertSolvent(positionIds);

        // And: The increase reopened the penalty window on the first position if the gauge penalises.
        if (penaltyRate > 0 && minStakeBlocks > 0) {
            // When: The first user claims its position rewards inside the window.
            // Then: It reverts.
            vm.prank(users.accountOwner);
            vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
            stakedMetadex03AM.claimReward(positionIds[0]);

            // And: The AM balance still covers all credited position rewards.
            assertSolvent(positionIds);

            // And: The window is left to close.
            vm.roll(vm.getBlockNumber() + minStakeBlocks);
        }

        // When: The first user claims its position rewards outside the window.
        vm.prank(users.accountOwner);
        stakedMetadex03AM.claimReward(positionIds[0]);

        // Then: The AM balance covers all credited position rewards.
        assertSolvent(positionIds);

        // When: The second user decreases its full position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03AM.decreaseLiquidity(positionIds[1], amountSecond);

        // Then: The AM balance covers all credited position rewards.
        assertSolvent(positionIds);
    }

    function testFuzz_Success_stakeAndClaim_PenaltyPerGaugeFactory(
        uint128 amount,
        uint256 minStakeBlocks,
        uint256 penaltyRate
    ) public {
        // Given: A stable and a volatile pool of the same pair, each with its own gauge.
        IMetadex03V2Pool stablePool = createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), true);
        IMetadex03V2Pool volatilePool =
            createPoolMetadex03(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.startPrank(users.owner);
        metadex03PoolAM.addAsset(address(stablePool));
        metadex03PoolAM.addAsset(address(volatilePool));
        vm.stopPrank();

        // And: Both gauges are added to the Asset Module.
        address stableGauge = address(createGaugeMetadex03(address(stablePool)));
        address volatileGauge = address(createGaugeMetadex03(address(volatilePool)));
        stakedMetadex03AM.addAsset(stableGauge);
        stakedMetadex03AM.addAsset(volatileGauge);

        // And: Only the stable GaugeFactory penalises an early unstake.
        minStakeBlocks = bound(minStakeBlocks, 1, MAX_MIN_STAKE_BLOCKS);
        penaltyRate = bound(penaltyRate, 1, MAX_PIPS);
        setPenaltyConfig(stableGauge, minStakeBlocks, penaltyRate);
        setPenaltyConfig(volatileGauge, 0, 0);

        // And: A position on each pool is staked.
        (uint256 staked, uint256 positionIdStable) = _dealAndStake(address(stablePool), amount);
        (, uint256 positionIdVolatile) = _dealAndStake(address(volatilePool), staked);
        deal(address(stablePool), address(stakedMetadex03AM), staked);
        deal(address(volatilePool), address(stakedMetadex03AM), staked);

        // When: A second stake is made on the volatile position.
        // Then: It succeeds, its own factory configured no penalty.
        stakedMetadex03AM.stakeAndClaim(positionIdVolatile, address(volatilePool), staked);

        // And: A second stake on the stable position reverts, each gauge follows its own factory.
        vm.expectRevert(StakedMetadex03AM.PenaltyWindowOpen.selector);
        stakedMetadex03AM.stakeAndClaim(positionIdStable, address(stablePool), staked);
    }
}
