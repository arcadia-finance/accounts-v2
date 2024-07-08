/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractStakingAM_Fuzz_Test } from "./_AbstractStakingAM.fuzz.t.sol";

import { StakingAMMock } from "../../../utils/mocks/asset-modules/StakingAMMock.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "StakingAM".
 */
contract Initialize_AbstractStakingAM_Fuzz_Test is AbstractStakingAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractStakingAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_initialize_NotOwner(address _unprivilegedAddress) public {
        vm.prank(users.owner);
        StakingAMMock assetModule = new StakingAMMock(address(registry), "StakingAMTest", "SMT", address(rewardToken));

        // Given : unprivileged address is not the owner of the AM.
        vm.assume(_unprivilegedAddress != users.owner);

        // When : Calling initialize().
        // Then : It should revert.
        vm.startPrank(_unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
        vm.stopPrank();
    }

    function testFuzz_success_initialize() public {
        StakingAMMock assetModule = new StakingAMMock(address(registry), "StakingAMTest", "SMT", address(rewardToken));

        // Given : Asset Module is added to the Registry.
        vm.prank(users.owner);
        registry.addAssetModule(address(assetModule));

        // When : Calling initialize().
        assetModule.initialize();

        // Then : The Asset Module should be added to the Registry as an asset.
        assertTrue(registry.inRegistry(address(assetModule)));

        // And : The assetModule is added to itself as an asset.
        assertTrue(assetModule.inAssetModule(address(assetModule)));
    }
}
