/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { StakedAerodromeAM_Fuzz_Test } from "./_StakedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "WithdrawAndClaim" function of contract "StakedAerodromeAM".
 */
contract WithdrawAndClaim_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_withdrawAndClaim(uint256 stakedAmount, uint256 toWithdraw, uint256 emissions) public {
        // Given: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: The aeroGauge of the aeroPool is added to the Asset Module.
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: A non-zero amount of aeroPool tokens is staked via the Asset Module.
        vm.assume(stakedAmount != 0);
        deal(address(aeroPool), address(stakedAerodromeAM), stakedAmount);
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), stakedAmount);

        // And: Emissions accrue, above the epoch the aeroGauge spreads them over.
        emissions = bound(emissions, 1 weeks, type(uint128).max);
        addEmissionsToGauge(aeroGauge, emissions);

        // And: Rewards accumulate over three days.
        vm.warp(block.timestamp + 3 days);
        uint256 earned = aeroGauge.earned(address(stakedAerodromeAM));

        // And: A non-zero part of the staked balance is withdrawn.
        toWithdraw = bound(toWithdraw, 1, stakedAmount);

        // When: Withdrawing LP's from the aeroGauge.
        stakedAerodromeAM.withdrawAndClaim(address(aeroPool), toWithdraw);

        // Then: The updated balance should be correct and rewards should have been claimed.
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), stakedAmount - toWithdraw);
        assertEq(aeroPool.balanceOf(address(stakedAerodromeAM)), toWithdraw);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), earned);
    }

    function testFuzz_Success_withdrawAndClaim_ZeroClaim(uint256 stakedAmount, uint256 toWithdraw) public {
        // Given: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: The aeroGauge of the aeroPool is added to the Asset Module.
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: A non-zero amount of aeroPool tokens is staked via the Asset Module.
        vm.assume(stakedAmount != 0);
        deal(address(aeroPool), address(stakedAerodromeAM), stakedAmount);
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), stakedAmount);

        // And: A non-zero part of the staked balance is withdrawn.
        toWithdraw = bound(toWithdraw, 1, stakedAmount);

        // When: Withdrawing LP's from the aeroGauge.
        stakedAerodromeAM.withdrawAndClaim(address(aeroPool), toWithdraw);

        // Then: The updated balance should be correct.
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), stakedAmount - toWithdraw);
        assertEq(aeroPool.balanceOf(address(stakedAerodromeAM)), toWithdraw);
    }
}
