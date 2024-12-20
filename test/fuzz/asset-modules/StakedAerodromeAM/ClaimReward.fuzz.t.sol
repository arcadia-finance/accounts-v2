/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

import { StakedAerodromeAM_Fuzz_Test, StakedAerodromeAM } from "./_StakedAerodromeAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

/**
 * @notice Fuzz tests for the "ClaimReward" function of contract "StakedAerodromeAM".
 */
contract ClaimReward_StakedAerodromeAM_Fuzz_Test is StakedAerodromeAM_Fuzz_Test {
    /*///////////////////////////////////////////////////////////////
                            SET-UP FUNCTION
    ///////////////////////////////////////////////////////////////*/

    function setUp() public override {
        StakedAerodromeAM_Fuzz_Test.setUp();
    }

    /*///////////////////////////////////////////////////////////////
                            FUZZ TESTS
    ///////////////////////////////////////////////////////////////*/

    function testFuzz_Success_ClaimReward(uint256 lpBalance, uint256 emissions) public {
        lpBalance = bound(lpBalance, 1, type(uint112).max);
        // Given : In order to avoid earned() to overflow we limit emissions to uint128.max.
        // Such an amount should never be distributed to a particular aeroGauge.
        emissions = bound(emissions, 1e18, type(uint128).max);

        // Given : the aeroPool is allowed in the Registry
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // Given : Valid aeroGauge
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);

        // And : Add asset and aeroGauge to the AM
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And : Add emissions to the Gauge
        // In order to avoid earned() to overflow we limit emissions to uint128.max.
        // Such an amount should never be distributed to a specific aeroGauge.
        emissions = bound(emissions, 1e18, type(uint128).max);
        addEmissionsToGauge(aeroGauge, emissions);

        // Given : Send aeroPool tokens to the AM.
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);

        // And : LP is staked via the stakedAerodromeAM
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        // And : We let rewards accumulate
        vm.warp(block.timestamp + 3 days);

        // When : Calling getCurrentReward()
        uint256 earned = aeroGauge.earned(address(stakedAerodromeAM));
        stakedAerodromeAM.claimReward(address(aeroPool));

        // Then : Earned emissions should have been transferred to the staked Aerodrome AM
        assertEq(ERC20(AERO).balanceOf(address(stakedAerodromeAM)), earned);
    }
}
