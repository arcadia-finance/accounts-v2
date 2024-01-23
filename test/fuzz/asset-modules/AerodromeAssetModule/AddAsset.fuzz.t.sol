/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AerodromeAssetModule_Fuzz_Test, AerodromeAssetModule, ERC20Mock } from "./_AerodromeAssetModule.fuzz.t.sol";
import { AerodromePoolMock } from "../../../utils/mocks/Aerodrome/PoolMock.sol";
import { StakingModule } from "../../../../src/asset-modules/staking-module/AbstractStakingModule.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "AerodromeAssetModule".
 */
contract AddAsset_AerodromeAssetModule_Fuzz_Test is AerodromeAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AerodromeAssetModule_Fuzz_Test.setUp();
    }

    function testFuzz_Revert_addAsset_NotOwner(address unprivilegedAddress, address pool_, address gauge_) public {
        // Given : The caller is not the owner.
        vm.assume(unprivilegedAddress != users.creatorAddress);

        // When : Calling addAsset().
        // Then : It should revert.
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        aerodromeAssetModule.addAsset(pool_, gauge_);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_AssetAlreadyAdded(address pool_, address gauge_) public {
        // Given : A gauge is already set for an Asset.
        aerodromeAssetModule.setAssetToGauge(pool_, gauge_);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(AerodromeAssetModule.AssetAlreadyAdded.selector);
        aerodromeAssetModule.addAsset(pool_, gauge_);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_PoolOrGaugeNotValid(address randomAddress) public {
        // Given : The stakingToken in the gauge is not equal to the pool address.
        vm.assume(randomAddress != address(pool));
        gauge.setStakingToken(randomAddress);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(AerodromeAssetModule.PoolOrGaugeNotValid.selector);
        aerodromeAssetModule.addAsset(address(pool), address(gauge));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_Token0NotAllowed(address token0) public notTestContracts(token0) {
        // Given : Token 0 and token 1 are set in the pool.
        // And : Token 1 is allowed in the registry, token 0 is not.
        assertEq(registryExtension.isAllowed(address(mockERC20.token1), 0), true);
        assertEq(registryExtension.isAllowed(token0, 0), false);
        pool.setTokens(token0, address(mockERC20.token1));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StakingModule.AssetNotAllowed.selector);
        aerodromeAssetModule.addAsset(address(pool), address(gauge));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_Token1NotAllowed(address token1) public notTestContracts(token1) {
        // Given : Token 0 and token 1 are set in the pool.
        // And : Token 0 is allowed in the registry, token 1 is not.
        assertEq(registryExtension.isAllowed(address(mockERC20.token1), 0), true);
        assertEq(registryExtension.isAllowed(token1, 0), false);
        pool.setTokens(address(mockERC20.token1), token1);

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StakingModule.AssetNotAllowed.selector);
        aerodromeAssetModule.addAsset(address(pool), address(gauge));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_RewardTokenNotAllowed(address rewardToken) public notTestContracts(rewardToken) {
        // Given : Token 0 and token 1 are set in the pool and both are allowed in the registry.
        pool.setTokens(address(mockERC20.token1), address(mockERC20.stable1));

        // Given : No asset module is set for the rewardToken
        registryExtension.setAssetToAssetModule(address(aerodromeAssetModule.rewardToken()), address(0));

        // When : An asset is added to the AM.
        // Then : It should revert.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(AerodromeAssetModule.RewardTokenNotAllowed.selector);
        aerodromeAssetModule.addAsset(address(pool), address(gauge));
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset() public {
        // Given : Token 0 and token 1 are set in the pool and both are allowed in the registry.
        pool.setTokens(address(mockERC20.token1), address(mockERC20.stable1));

        // When : An Asset is added to AM.
        vm.prank(users.creatorAddress);
        aerodromeAssetModule.addAsset(address(pool), address(gauge));

        // Then : Information should be set and correct
        assertEq(aerodromeAssetModule.assetToGauge(address(pool)), address(gauge));

        assertEq(
            aerodromeAssetModule.assetToUnderlyingAssets(aerodromeAssetModule.getKeyFromAsset(address(pool), 0), 0),
            aerodromeAssetModule.getKeyFromAsset(address(mockERC20.token1), 0)
        );
        assertEq(
            aerodromeAssetModule.assetToUnderlyingAssets(aerodromeAssetModule.getKeyFromAsset(address(pool), 0), 1),
            aerodromeAssetModule.getKeyFromAsset(address(mockERC20.stable1), 0)
        );
        assertEq(
            aerodromeAssetModule.assetToUnderlyingAssets(aerodromeAssetModule.getKeyFromAsset(address(pool), 0), 2),
            aerodromeAssetModule.getKeyFromAsset(address(aerodromeAssetModule.rewardToken()), 0)
        );
    }
}
