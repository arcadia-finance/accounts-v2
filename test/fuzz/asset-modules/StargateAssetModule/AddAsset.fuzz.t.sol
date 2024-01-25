/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test, StargateAssetModule, ERC20Mock } from "./_StargateAssetModule.fuzz.t.sol";
import { StargatePoolMock } from "../../../utils/mocks/Stargate/StargatePoolMock.sol";
import { StakingModule } from "../../../../src/asset-modules/staking-module/AbstractStakingModule.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "StargateAssetModule".
 */
contract AddAsset_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */
    function testFuzz_Revert_addAsset_AssetAndRewardAlreadySet(uint96 poolId) public {
        // Given : An Asset is already set.
        poolMock.setToken(address(mockERC20.token1));
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(poolMock));
        vm.prank(users.creatorAddress);
        stargateAssetModule.addAsset(poolId);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StargateAssetModule.AssetAlreadySet.selector);
        stargateAssetModule.addAsset(poolId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_BadPool(uint96 poolId) public {
        // Given : Address returned from lpStakingTime for a specific pool id is not the pool address
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(0));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StargateAssetModule.BadPool.selector);
        stargateAssetModule.addAsset(poolId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_AssetNotAllowed(address poolUnderlyingToken, uint96 poolId)
        public
        notTestContracts(poolUnderlyingToken)
    {
        // Given : The pool underlying token is not allowed in the Registry.
        vm.assume(poolUnderlyingToken != address(lpStakingTimeMock.eToken()));
        poolMock.setToken(poolUnderlyingToken);

        // Given : poolInfo is correct
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(poolMock));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StakingModule.AssetNotAllowed.selector);
        stargateAssetModule.addAsset(poolId);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint96 poolId) public {
        // Given : The underlying token of the pool is an asset added to the Registry
        poolMock.setToken(address(mockERC20.token1));

        // Given : poolInfo is correct
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(poolMock));

        // When : An Asset is added to AM.
        vm.prank(users.creatorAddress);
        stargateAssetModule.addAsset(poolId);

        // Then : Information should be set and correct
        assertEq(address(stargateAssetModule.REWARD_TOKEN()), address(lpStakingTimeMock.eToken()));
        (address underlyingAsset, uint96 poolId_) = stargateAssetModule.poolInformation(address(poolMock));
        assertEq(poolId_, poolId);
        assertEq(underlyingAsset, address(mockERC20.token1));
    }
}
