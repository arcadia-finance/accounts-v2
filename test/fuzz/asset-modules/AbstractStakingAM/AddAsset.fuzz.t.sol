/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AbstractStakingAM_Fuzz_Test, StakingAM } from "./_AbstractStakingAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_addAsset" of contract "StakingAM".
 */
contract AddAsset_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_addAsset(address asset) public {
        // When : The Asset is added.
        stakingAM.addAsset(asset);

        // Then : The Asset is allowed, and no accounting state is initialised.
        StakingAM.AssetState memory assetState;
        (assetState.lastRewardPerTokenGlobal, assetState.totalStaked, assetState.allowed) = stakingAM.assetState(asset);
        assertTrue(assetState.allowed);
        assertEq(assetState.lastRewardPerTokenGlobal, 0);
        assertEq(assetState.totalStaked, 0);
    }

    function testFuzz_Success_addAsset_AlreadyAdded(
        address asset,
        uint128 lastRewardPerTokenGlobal,
        uint128 totalStaked
    ) public {
        // Given : The Asset is added, and has accumulated accounting state.
        stakingAM.addAsset(asset);
        stakingAM.setLastRewardPerTokenGlobal(asset, lastRewardPerTokenGlobal);
        stakingAM.setTotalStaked(asset, totalStaked);

        // When : The Asset is added a second time.
        stakingAM.addAsset(asset);

        // Then : The Asset stays allowed, and its accounting state is untouched.
        StakingAM.AssetState memory assetState;
        (assetState.lastRewardPerTokenGlobal, assetState.totalStaked, assetState.allowed) = stakingAM.assetState(asset);
        assertTrue(assetState.allowed);
        assertEq(assetState.lastRewardPerTokenGlobal, lastRewardPerTokenGlobal);
        assertEq(assetState.totalStaked, totalStaked);
    }
}
