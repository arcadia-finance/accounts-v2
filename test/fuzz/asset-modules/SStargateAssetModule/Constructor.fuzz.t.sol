/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { SStargateAssetModule_Fuzz_Test } from "./_SStargateAssetModule.fuzz.t.sol";

import { SStargateAssetModule } from "../../../../src/asset-modules/Stargate-Finance/SStargateAssetModule.sol";

/**
 * @notice Fuzz tests for the constructor of contract "SStargateAssetModule".
 */
contract Constructor_SStargateAssetModule_Fuzz_Test is SStargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        SStargateAssetModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_constructor_RewardTokenNotAllowed() public {
        // Given: No asset module is set for the rewardToken
        registryExtension.setAssetToAssetModule(address(lpStakingTimeMock.eToken()), address(0));

        // When: An asset is added to the AM.
        // Then: It reverts.
        vm.prank(users.creatorAddress);
        vm.expectRevert(SStargateAssetModule.RewardTokenNotAllowed.selector);
        new SStargateAssetModule(address(registryExtension), address(lpStakingTimeMock));
    }

    function testFuzz_success_constructor() public {
        SStargateAssetModule assetModule =
            new SStargateAssetModule(address(registryExtension), address(lpStakingTimeMock));

        assertEq(address(assetModule.LP_STAKING_TIME()), address(lpStakingTimeMock));
        assertEq(address(assetModule.REWARD_TOKEN()), address(lpStakingTimeMock.eToken()));
        assertEq(assetModule.ASSET_TYPE(), 1);
        assertEq(assetModule.REGISTRY(), address(registryExtension));
        assertEq(assetModule.symbol(), "aSGP");
        assertEq(assetModule.name(), "Arcadia Stargate Positions");
    }
}
