/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

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

        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // Given : Send aeroPool tokens to the AM.
        deal(address(aeroPool), address(stakedAerodromeAM), stakedAmount);

        // And : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), stakedAmount);

        // When : Withdrawing LP's from the aeroGauge
        stakedAerodromeAM.withdrawAndClaim(address(aeroPool), toWithdraw);

        // Then : The updated balance should be correct
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), stakedAmount - toWithdraw);
        assertEq(aeroPool.balanceOf(address(stakedAerodromeAM)), toWithdraw);
    }

    function testFuzz_Success_WithdrawAndClaim(uint256 stakedAmount, uint256 toWithdraw, uint256 emissions) public {
        stakedAmount = bound(stakedAmount, 1, type(uint256).max);
        toWithdraw = bound(toWithdraw, 1, stakedAmount);

        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And : Send aeroPool tokens to the AM.
        deal(address(aeroPool), address(stakedAerodromeAM), stakedAmount);

        // And : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), stakedAmount);

        // And : Add emissions to aeroGauge
        // In order to avoid earned() to overflow we limit emissions to uint128.max.
        // Such an amount should never be distributed to a specific aeroGauge.
        emissions = bound(emissions, 1e18, type(uint128).max);
        addEmissionsToGauge(aeroGauge, emissions);

        // Given : Let rewards accumulate
        vm.warp(block.timestamp + 3 days);
        uint256 earned = aeroGauge.earned(address(stakedAerodromeAM));

        // When : Withdrawing LP's from the aeroGauge
        stakedAerodromeAM.withdrawAndClaim(address(aeroPool), toWithdraw);

        // Then : The updated balance should be correct
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), stakedAmount - toWithdraw);
        assertEq(aeroPool.balanceOf(address(stakedAerodromeAM)), toWithdraw);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), earned);
    }
}
