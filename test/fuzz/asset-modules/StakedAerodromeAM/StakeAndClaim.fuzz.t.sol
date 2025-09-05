/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

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

        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // Given : Send aeroPool tokens to the AM.
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);

        // When : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        // Then : The updated balance should be correct
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), lpBalance);
    }

    function testFuzz_Success_StakeAndClaim(uint256 lpBalance, uint256 emissions) public {
        lpBalance = bound(lpBalance, 1, type(uint128).max);

        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // Given : An initial stake via the stakedAerodromeAM
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        // Given : Add emissions to aeroGauge
        // In order to avoid earned() to overflow we limit emissions to uint128.max.
        // Such an amount should never be distributed to a specific aeroGauge.
        emissions = bound(emissions, 1e18, type(uint128).max);
        addEmissionsToGauge(aeroGauge, emissions);

        // Given : Let rewards accumulate
        vm.warp(block.timestamp + 3 days);
        uint256 earned = aeroGauge.earned(address(stakedAerodromeAM));

        // When : An additional amount is staked via the AM
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        // Then : The updated balance should be correct and rewards should have been claimed
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), lpBalance * 2);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), earned);
    }
}
