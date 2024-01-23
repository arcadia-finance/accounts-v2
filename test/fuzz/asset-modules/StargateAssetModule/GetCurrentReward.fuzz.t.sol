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

/*    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    } */

/*     function testFuzz_success_getCurrentReward(uint256 poolId, uint256 tokenId, uint256 pendingEmissions) public {
        // Given : Set available rewards in lpStaking contract.
        lpStakingTimeMock.setInfoForPoolId(poolId, pendingEmissions, address(0x0));

        // And : A poolId is set in the AM for the specific tokenId
        stargateAssetModule.setTokenIdToPoolId(tokenId, poolId);

        // When : _getCurrentReward is called on the tokenId.
        uint256 currentReward = stargateAssetModule.getCurrentReward(tokenId);

        // Then : It should return the pending emissions.
        assertEq(currentReward, pendingEmissions);
    } */
}
