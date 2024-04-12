/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

import { StakedAerodromeAM_Fuzz_Test, StakedAerodromeAM } from "./_StakedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

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

        // And : the pool is allowed in the Registry
        deployAerodromePoolFixture(address(mockERC20.token1), address(mockERC20.stable1), false);

        // And : Valid gauge
        deployAerodromeGaugeFixture(address(pool), AERO);

        // And : Add asset and gauge to the AM
        stakedAerodromeAM.addAsset(address(gauge));

        // And : Add emissions to the Gauge
        addEmissionsToGauge(emissions);

        // And : Send pool tokens to the AM.
        deal(address(pool), address(stakedAerodromeAM), lpBalance);

        // And : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(pool), lpBalance);

        uint256 currentReward = stakedAerodromeAM.getCurrentReward(address(pool));
        assertEq(currentReward, 0);
        // And : We let rewards accumulate
        vm.warp(block.timestamp + 3 days);

        // When : Calling getCurrentReward()
        uint256 earned = gauge.earned(address(stakedAerodromeAM));
        currentReward = stakedAerodromeAM.getCurrentReward(address(pool));

        // Then : Current reward should be equal to earned amount in gauge
        assertEq(currentReward, earned);
    }
}
