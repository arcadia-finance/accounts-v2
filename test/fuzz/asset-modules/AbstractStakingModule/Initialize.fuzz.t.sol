/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingModule_Fuzz_Test } from "./_AbstractStakingModule.fuzz.t.sol";

import { StakingModuleMock } from "../../../utils/mocks/StakingModuleMock.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "StakingModule".
 */
contract Initialize_AbstractStakingModule_Fuzz_Test is AbstractStakingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingModule_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_revert_initialize_NotOwner(address _unprivilegedAddress) public {
        vm.prank(users.creatorAddress);
        StakingModuleMock assetModule =
            new StakingModuleMock(address(registryExtension), "StakingModuleTest", "SMT", address(rewardToken));

        // Given : unprivileged address is not the owner of the AM.
        vm.assume(_unprivilegedAddress != users.creatorAddress);

        // When : Calling initialize().
        // Then : It should revert.
        vm.startPrank(_unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
        vm.stopPrank();
    }

    function testFuzz_success_initialize() public {
        StakingModuleMock assetModule =
            new StakingModuleMock(address(registryExtension), "StakingModuleTest", "SMT", address(rewardToken));

        // Given : Asset Module is added to the Registry.
        vm.prank(users.creatorAddress);
        registryExtension.addAssetModule(address(assetModule));

        // When : Calling initialize().
        assetModule.initialize();

        // Then : The Asset Module should be added to the Registry as an asset.
        assertTrue(registryExtension.inRegistry(address(assetModule)));

        // And : The assetModule is added to itself as an asset.
        assertTrue(assetModule.inAssetModule(address(assetModule)));
    }
}
