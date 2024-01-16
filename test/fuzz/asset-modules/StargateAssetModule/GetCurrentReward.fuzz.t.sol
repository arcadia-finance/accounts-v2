/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test, StargateAssetModule } from "./_StargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getCurrentReward" of contract "StargateAssetModule".
 */
contract GetCurrentReward_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    // Note : This will mainly be tested via fork testing to ensure pendingEmissionToken() function works as intended in lpStakingTime.sol.
    function testFuzz_success_getCurrentReward(uint256 poolId, uint256 pendingEmissions) public {
        // Given : The pool id is set for the Asset in the AM.
        stargateAssetModule.setAssetToPoolId(address(poolMock), poolId);

        // Given : Set available rewards in lpStaking contract.
        lpStakingTimeMock.setInfoForPoolId(poolId, pendingEmissions, address(poolMock));

        // When : _getCurrentReward is called for a specific asset.
        uint256 currentReward = stargateAssetModule.getCurrentReward(address(poolMock));

        // Then : It should return the pending emissions.
        assertEq(currentReward, pendingEmissions);
    }
}
