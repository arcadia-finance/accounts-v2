/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { StakedAerodromeAM_Fuzz_Test } from "./_StakedAerodromeAM.fuzz.t.sol";

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

    function testFuzz_Success_claimReward(uint256 lpBalance, uint256 emissions) public {
        // Given: The aeroPool is allowed in the Registry.
        aeroPool = createPoolAerodrome(address(mockERC20.token1), address(mockERC20.stable1), false);
        vm.prank(users.owner);
        aerodromePoolAM.addAsset(address(aeroPool));

        // And: The aeroGauge of the aeroPool is added to the Asset Module.
        aeroGauge = createGaugeAerodrome(aeroPool, AERO);
        stakedAerodromeAM.addAsset(address(aeroGauge));

        // And: A non-zero LP balance is staked via the Asset Module.
        vm.assume(lpBalance != 0);
        deal(address(aeroPool), address(stakedAerodromeAM), lpBalance);
        stakedAerodromeAM.stakeAndClaim(address(aeroPool), lpBalance);

        // And: Emissions accrue, above the epoch the aeroGauge spreads them over.
        emissions = bound(emissions, 1 weeks, type(uint128).max);
        addEmissionsToGauge(aeroGauge, emissions);

        // And: Rewards accumulate over three days.
        vm.warp(block.timestamp + 3 days);
        uint256 earned = aeroGauge.earned(address(stakedAerodromeAM));

        // When: The Asset Module claims.
        stakedAerodromeAM.claimReward(address(aeroPool));

        // Then: The earned emissions are transferred to the Asset Module.
        assertEq(ERC20(AERO).balanceOf(address(stakedAerodromeAM)), earned);
    }
}
