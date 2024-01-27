/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "StakingAM".
 */
contract GetUnderlyingAssets_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets(address underLyingAsset, uint96 positionId) public {
        // Given : Set Asset for positionId
        stakingAM.setAssetInPosition(underLyingAsset, positionId);

        // When : Calling getUnderlyingAssets()
        bytes32 assetKey = stakingAM.getKeyFromAsset(address(stakingAM), positionId);
        bytes32[] memory underlyingAssetKeys = stakingAM.getUnderlyingAssets(assetKey);

        // Then : Underlying assets returned should be correct
        assertEq(underlyingAssetKeys[0], stakingAM.getKeyFromAsset(underLyingAsset, 0));
        assertEq(underlyingAssetKeys[1], stakingAM.getKeyFromAsset(address(stakingAM.REWARD_TOKEN()), 0));
    }
}
