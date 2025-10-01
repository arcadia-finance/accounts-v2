/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { StakedAerodromeAM_Fuzz_Test } from "./_StakedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the "GetCurrentReward" function of contract "StakedAerodromeAM".
 */
contract GetCurrentReward_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_GetCurrentReward(uint256 lpBalance, uint256 emissions) public {
        lpBalance = bound(lpBalance, 1, type(uint256).max);

        // And : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And : Add emissions to the Gauge
        // In order to avoid earned() to overflow we limit emissions to uint128.max.
        // Such an amount should never be distributed to a specific aeroGauge.
        emissions = bound(emissions, 1e18, type(uint128).max);
        addEmissionsToGauge(aeroGauge, emissions);

        // And : Send aeroPool tokens to the AM.
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);

        // And : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        uint256 currentReward = stakedAerodromeAM.getCurrentReward(address(aeroPool));
        assertEq(currentReward, 0);
        // And : We let rewards accumulate
        vm.warp(block.timestamp + 3 days);

        // When : Calling getCurrentReward()
        uint256 earned = aeroGauge.earned(address(stakedAerodromeAM));
        currentReward = stakedAerodromeAM.getCurrentReward(address(aeroPool));

        // Then : Current reward should be equal to earned amount in aeroGauge
        assertEq(currentReward, earned);
    }
}
