/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeAssetModule_Fuzz_Test } from "./_AerodromeAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "claimReward" of contract "AerodromeAssetModule".
 */
contract ClaimReward_AerodromeAssetModule_Fuzz_Test is AerodromeAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_claimReward(uint256 amountClaimable) public {
        // Given : An Asset has been added and mapping set for gauge
        aerodromeAssetModule.setAssetToGauge(address(pool), address(gauge));

        // And : Rewards are claimable in gauge
        address rewardToken = address(aerodromeAssetModule.rewardToken());
        gauge.setRewardToken(rewardToken);
        gauge.setEarnedForAddress(address(aerodromeAssetModule), amountClaimable);
        deal(rewardToken, address(gauge), amountClaimable);

        // When : Calling claimReward
        aerodromeAssetModule.claimReward(address(pool));

        // Then : Rewards should be transfered to the AM
        assertEq(aerodromeAssetModule.rewardToken().balanceOf(address(aerodromeAssetModule)), amountClaimable);
    }
}
