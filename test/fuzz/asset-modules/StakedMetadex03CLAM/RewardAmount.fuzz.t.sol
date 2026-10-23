/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";

/**
 * @notice Fuzz tests for the function "_rewardAmount" of contract "StakedMetadex03CLAM".
 */
contract RewardAmount_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Success_rewardAmount(
        StakedSlipstreamAM.PositionState memory position,
        uint256 emissions,
        int24 tick
    ) public {
        // Given: A staked position whose emissions exceed the wei its share can round away.
        emissions = bound(emissions, 2, MAX_BASE_RATE);
        uint256 assetId = _initStakedPositionWithEarned(position, emissions, tick);
        assertGt(stakedMetadex03CLAM.rewardOf(assetId), 0);

        // When: Calling _rewardAmount().
        // Then: Nothing is valued, the gauge can defer the reward on a withdrawal.
        assertEq(stakedMetadex03CLAM.rewardAmount(assetId), 0);
    }
}
