/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeAssetModule_Fuzz_Test } from "./_AerodromeAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getCurrentReward" of contract "AerodromeAssetModule".
 */
contract GetCurrentReward_AerodromeAssetModule_Fuzz_Test is AerodromeAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_success_getCurrentReward(uint256 amountClaimable) public {
        // Given : An Asset has been added and mapping set for gauge
        aerodromeAssetModule.setAssetToGauge(address(pool), address(gauge));

        // And : Rewards are claimable in gauge for AM
        address rewardToken = address(aerodromeAssetModule.rewardToken());
        gauge.setRewardToken(rewardToken);
        gauge.setEarnedForAddress(address(aerodromeAssetModule), amountClaimable);

        // When : Calling getCurrentReward()
        uint256 currentReward = aerodromeAssetModule.getCurrentReward(address(pool));

        // Then : It should return correct value
        assertEq(currentReward, amountClaimable);
    }
}
