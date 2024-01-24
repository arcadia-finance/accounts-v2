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

    function testFuzz_Revert_addAsset_BadPool(uint256 poolId) public {
        // Given : Address returned from lpStakingTime for a specific pool id is not the pool address
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(0));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StargateAssetModule.BadPool.selector);
        stargateAssetModule.addAsset(poolId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_DecimalsGreaterThan18(uint256 poolId, uint8 decimals) public {
        // Given : Pool lp token decimals is greater than 18
        decimals = uint8(bound(decimals, 19, type(uint8).max));
        StargatePoolMock poolMock_ = new StargatePoolMock(decimals);

        // And : poolInfo is correct
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(poolMock_));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StargateAssetModule.InvalidTokenDecimals.selector);
        stargateAssetModule.addAsset(poolId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_AssetAndRewardAlreadySet(uint256 poolId) public {
        // Given : An Asset and reward token pair are already set.
        ERC20Mock rewardToken = new ERC20Mock("xxx", "xxx", 18);
        stargateAssetModule.setAssetToRewardToken(address(poolMock), rewardToken);

        // And : poolInfo is correct
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(poolMock));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StargateAssetModule.AssetAndRewardPairAlreadySet.selector);
        stargateAssetModule.addAsset(poolId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_AssetNotAllowed(address poolUnderlyingToken, uint256 poolId)
        public
        notTestContracts(poolUnderlyingToken)
    {
        // Given : The pool underlying token is not allowed in the Registry.
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

    function testFuzz_Success_addAsset(uint256 poolId, uint256 convertRate) public {
        // Given : The underlying token of the pool is an asset added to the Registry
        poolMock.setToken(address(mockERC20.token1));

        // Given : poolInfo is correct
        lpStakingTimeMock.setInfoForPoolId(poolId, 0, address(poolMock));

        // Given : ConvertRate is set
        poolMock.setConvertRate(convertRate);

        // When : An Asset is added to AM.
        vm.prank(users.creatorAddress);
        stargateAssetModule.addAsset(poolId);

        // Then : Information should be set and correct
        assertEq(stargateAssetModule.assetToPoolId(address(poolMock)), poolId);
        assertEq(
            address(stargateAssetModule.assetToRewardToken(address(poolMock))),
            address(stargateAssetModule.REWARD_TOKEN())
        );
        assertEq(stargateAssetModule.assetToUnderlyingAsset(address(poolMock)), address(mockERC20.token1));
        assertEq(stargateAssetModule.assetToConversionRate(address(poolMock)), convertRate);
    }
}
