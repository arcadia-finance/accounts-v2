/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakedStargateAM_Fuzz_Test } from "./_StakedStargateAM.fuzz.t.sol";
import { StakedStargateAM } from "../../../../src/asset-modules/Stargate-Finance/StakedStargateAM.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "StakedStargateAM".
 */
contract AddAsset_StakedStargateAM_Fuzz_Test is StakedStargateAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedStargateAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_addAsset_PoolNotAllowed(uint256 pid) public {
        // Given : Address returned from lpStakingTime for a specific pool id is not the pool address
        lpStakingTimeMock.setInfoForPoolId(pid, 0, address(0));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StakedStargateAM.PoolNotAllowed.selector);
        stakedStargateAM.addAsset(pid);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_AssetAlreadySet(uint256 poolId, uint256 pid) public {
        // Given: Pool is added to the StargateAssetModule.
        sgFactoryMock.setPool(poolId, address(poolMock));
        poolMock.setToken(address(mockERC20.token1));
        stargateAssetModule.addAsset(poolId);

        // Given : An Asset is already set.
        poolMock.setToken(address(mockERC20.token1));
        lpStakingTimeMock.setInfoForPoolId(pid, 0, address(poolMock));
        vm.prank(users.creatorAddress);
        stakedStargateAM.addAsset(pid);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StakedStargateAM.AssetAlreadySet.selector);
        stakedStargateAM.addAsset(pid);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint256 poolId, uint256 pid) public {
        // Given: Pool is added to the StargateAssetModule.
        sgFactoryMock.setPool(poolId, address(poolMock));
        poolMock.setToken(address(mockERC20.token1));
        stargateAssetModule.addAsset(poolId);

        // And : poolInfo is correct
        lpStakingTimeMock.setInfoForPoolId(pid, 0, address(poolMock));

        // When : An Asset is added to AM.
        vm.prank(users.creatorAddress);
        stakedStargateAM.addAsset(pid);

        // Then : Information should be set and correct
        assertEq(stakedStargateAM.assetToPid(address(poolMock)), pid);

        (bool allowed,,,) = stakedStargateAM.assetState(address(poolMock));
        assertTrue(allowed);
    }
}
