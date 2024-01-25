/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { SStargateAssetModule_Fuzz_Test } from "./_SStargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getCurrentReward" of contract "SStargateAssetModule".
 */
contract GetCurrentReward_SStargateAssetModule_Fuzz_Test is SStargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        SStargateAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    // Note : This will mainly be tested via fork testing to ensure pendingEmissionToken() function works as intended in lpStakingTime.sol.
    function testFuzz_success_getCurrentReward(uint256 pid, uint256 pendingEmissions) public {
        // Given : The pool id is set for the asset in the AM.
        stakedStargateAM.setAssetToPoolId(address(poolMock), pid);

        // Given : Set available rewards in lpStaking contract.
        lpStakingTimeMock.setInfoForPoolId(pid, pendingEmissions, address(poolMock));

        // When : _getCurrentReward is called for a specific asset.
        uint256 currentReward = stakedStargateAM.getCurrentReward(address(poolMock));

        // Then : It should return the pending emissions.
        assertEq(currentReward, pendingEmissions);
    }
}
