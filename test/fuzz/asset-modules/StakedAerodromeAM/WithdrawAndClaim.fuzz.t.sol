/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedAerodromeAM_Fuzz_Test, StakedAerodromeAM } from "./_StakedAerodromeAM.fuzz.t.sol";

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

    function testFuzz_Success_WithdrawAndClaim_ZeroClaim(uint256 stakedAmount, uint256 toWithdraw) public {
        stakedAmount = bound(stakedAmount, 1, type(uint256).max);
        toWithdraw = bound(toWithdraw, 1, stakedAmount);

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Given : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given : Send pool tokens to the AM.
        deal(address(pool), address(stakedAerodromeAM), stakedAmount);

        // And : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(pool), stakedAmount);

        // When : Withdrawing LP's from the gauge
        stakedAerodromeAM.withdrawAndClaim(address(pool), toWithdraw);

        // Then : The updated balance should be correct
        assertEq(gauge.balanceOf(address(stakedAerodromeAM)), stakedAmount - toWithdraw);
        assertEq(pool.balanceOf(address(stakedAerodromeAM)), toWithdraw);
    }

    function testFuzz_Success_WithdrawAndClaim(uint256 stakedAmount, uint256 toWithdraw, uint256 emissions) public {
        stakedAmount = bound(stakedAmount, 1, type(uint256).max);
        toWithdraw = bound(toWithdraw, 1, stakedAmount);

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Given : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // And : Send pool tokens to the AM.
        deal(address(pool), address(stakedAerodromeAM), stakedAmount);

        // And : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(pool), stakedAmount);

        // And : Add emissions to gauge
        addEmissionsToGauge(emissions);

        // Given : Let rewards accumulate
        vm.warp(block.timestamp + 3 days);
        uint256 earned = gauge.earned(address(stakedAerodromeAM));

        // When : Withdrawing LP's from the gauge
        stakedAerodromeAM.withdrawAndClaim(address(pool), toWithdraw);

        // Then : The updated balance should be correct
        assertEq(gauge.balanceOf(address(stakedAerodromeAM)), stakedAmount - toWithdraw);
        assertEq(pool.balanceOf(address(stakedAerodromeAM)), toWithdraw);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), earned);
    }
}
