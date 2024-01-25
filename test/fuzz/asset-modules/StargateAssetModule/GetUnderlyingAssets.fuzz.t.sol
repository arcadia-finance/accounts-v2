/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test } from "./_StargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "StargateAssetModule".
 */
contract GetUnderlyingAssets_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Success_getUnderlyingAssets(uint96 positionId, uint96 poolId) public {
        // Given : The underlying token of the pool is an asset added to the Registry
        poolMock.setToken(address(mockERC20.token1));

        // Given : poolInfo is correct
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(poolMock));

        // Given : The Asset is added to AM.
        vm.prank(users.creatorAddress);
        stargateAssetModule.addAsset(poolId);

        // Given : Set Asset for positionId
        stargateAssetModule.setAssetInPosition(address(poolMock), positionId);

        // When : Calling getUnderlyingAssets()
        bytes32 assetKey = stargateAssetModule.getKeyFromAsset(address(stargateAssetModule), positionId);
        bytes32[] memory underlyingAssetKeys = stargateAssetModule.getUnderlyingAssets(assetKey);

        // Then : Underlying assets returned should be correct
        assertEq(underlyingAssetKeys[0], stargateAssetModule.getKeyFromAsset(address(poolMock.token()), 0));
        assertEq(
            underlyingAssetKeys[1], stargateAssetModule.getKeyFromAsset(address(stargateAssetModule.REWARD_TOKEN()), 0)
        );
    }
}
