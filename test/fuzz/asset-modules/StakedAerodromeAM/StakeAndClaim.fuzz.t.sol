/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { StakedAerodromeAM_Fuzz_Test } from "./_StakedAerodromeAM.fuzz.t.sol";

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

    function testFuzz_Success_stakeAndClaim(uint256 lpBalance, uint256 emissions) public {
        // Given: An LP balance that can be staked twice within the aeroGauge's uint256 supply.
        lpBalance = bound(lpBalance, 1, type(uint256).max / 2);

        // And: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: The aeroGauge of the aeroPool is added to the Asset Module.
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: An initial stake via the Asset Module.
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        // And: Emissions accrue, above the epoch the aeroGauge spreads them over.
        emissions = bound(emissions, 1 weeks, type(uint128).max);
        addEmissionsToGauge(aeroGauge, emissions);

        // And: Rewards accumulate over three days.
        vm.warp(block.timestamp + 3 days);
        uint256 earned = aeroGauge.earned(address(stakedAerodromeAM));

        // And: A second LP balance of the same size sits in the Asset Module.
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);

        // When: An additional amount is staked via the Asset Module.
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        // Then: The stake doubled and the pending rewards are claimed.
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), lpBalance * 2);
        assertEq(stakedAerodromeAM.REWARD_TOKEN().balanceOf(address(stakedAerodromeAM)), earned);
    }

    function testFuzz_Success_stakeAndClaim_ZeroClaim(uint256 lpBalance) public {
        // Given: A non-zero LP balance.
        vm.assume(lpBalance != 0);

        // And: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: The aeroGauge of the aeroPool is added to the Asset Module.
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: The LP balance sits in the Asset Module, no emissions accrued to the aeroGauge.
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);

        // When: The LP is staked via the Asset Module.
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        // Then: The full LP balance is staked.
        assertEq(aeroGauge.balanceOf(address(stakedAerodromeAM)), lpBalance);
    }
}
