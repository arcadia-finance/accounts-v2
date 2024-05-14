/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedAerodromeAM_Fuzz_Test, StakedAerodromeAM } from "./_StakedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "StakeAndClaim" function of contract "StakedAerodromeAM".
 */
contract StakeAndClaim_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_StakeAndClaim_ZeroClaim(uint256 lpBalance) public {
        lpBalance = bound(lpBalance, 1, type(uint256).max);

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Given : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given : Send pool tokens to the AM.
        deal(address(pool), address(stakedAerodromeAM), lpBalance);

        // When : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(pool), lpBalance);

        // Then : The updated balance should be correct
        assertEq(gauge.balanceOf(address(stakedAerodromeAM)), lpBalance);
    }

    function testFuzz_Success_StakeAndClaim(uint256 lpBalance, uint256 emissions) public {
        lpBalance = bound(lpBalance, 1, type(uint128).max);

        // Given : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // Given : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // Given : An initial stake via the stakedAerodromeAM
        deal(address(pool), address(stakedAerodromeAM), lpBalance);
        stakedAerodromeAM.stakeAndClaim(address(pool), lpBalance);

        // Given : Add emissions to gauge
        addEmissionsToGauge(emissions);

        // Given : Let rewards accumulate
        vm.warp(block.timestamp + 3 days);
        uint256 earned = gauge.earned(address(stakedAerodromeAM));

        // When : An additional amount is staked via the AM
        deal(address(pool), address(stakedAerodromeAM), lpBalance);
        stakedAerodromeAM.stakeAndClaim(address(pool), lpBalance);

        // Then : The updated balance should be correct and rewards should have been claimed
        assertEq(gauge.balanceOf(address(stakedAerodromeAM)), lpBalance * 2);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), earned);
    }
}
