/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "StakingModule".
 */
contract GetUnderlyingAssets_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets(address underLyingAsset, uint96 positionId) public {
        // Given : Set Asset for positionId
        stakingModule.setAssetInPosition(underLyingAsset, positionId);

        // When : Calling getUnderlyingAssets()
        bytes32 assetKey = stakingModule.getKeyFromAsset(address(stakingModule), positionId);
        bytes32[] memory underlyingAssetKeys = stakingModule.getUnderlyingAssets(assetKey);

        // Then : Underlying assets returned should be correct
        assertEq(underlyingAssetKeys[0], stakingModule.getKeyFromAsset(underLyingAsset, 0));
        assertEq(underlyingAssetKeys[1], stakingModule.getKeyFromAsset(address(stakingModule.REWARD_TOKEN()), 0));
    }
}
