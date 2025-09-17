/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "StakedSlipstreamAM".
 */
contract Initialize_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedSlipstreamAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_initialize_NotOwner(address unprivilegedAddress) public {
        // Given : unprivileged address is not the owner of the AM.
        vm.assume(unprivilegedAddress != users.owner);

        // And : Asset Module is deployed.
        vm.prank(users.owner);
        StakedSlipstreamAM assetModule = new StakedSlipstreamAM(
            users.owner, address(registry), address(slipstreamPositionManager), address(voter), address(AERO)
        );

        // When : Calling initialize().
        // Then : It should revert.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
    }

    function testFuzz_Revert_initialize_RewardTokenNotAllowed() public {
        // Given: No asset module is set for the rewardToken
        registry.setAssetModule(AERO, address(0));

        // And : Asset Module is deployed.
        vm.prank(users.owner);
        StakedSlipstreamAM assetModule = new StakedSlipstreamAM(
            users.owner, address(registry), address(slipstreamPositionManager), address(voter), address(AERO)
        );

        // When : Calling initialize().
        // Then : It should revert.
        vm.prank(users.owner);
        vm.expectRevert(StakedSlipstreamAM.RewardTokenNotAllowed.selector);
        assetModule.initialize();
    }

    function testFuzz_Revert_initialize_AlreadyInitialized() public {
        // Given : Asset Module is deployed.
        vm.prank(users.owner);
        StakedSlipstreamAM assetModule = new StakedSlipstreamAM(
            users.owner, address(registry), address(slipstreamPositionManager), address(voter), address(AERO)
        );

        // And : Asset Module is added to the Registry.
        vm.prank(users.owner);
        registry.addAssetModule(address(assetModule));

        // And : Asset Module is Initialized.
        vm.prank(users.owner);
        assetModule.initialize();

        // When : Calling initialize().
        // Then : It should revert.
        vm.prank(users.owner);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        assetModule.initialize();
    }

    function testFuzz_success_initialize() public {
        // Given : Asset Module is deployed.
        vm.prank(users.owner);
        StakedSlipstreamAM assetModule = new StakedSlipstreamAM(
            users.owner, address(registry), address(slipstreamPositionManager), address(voter), address(AERO)
        );

        // And : Asset Module is added to the Registry.
        vm.prank(users.owner);
        registry.addAssetModule(address(assetModule));

        // When : Calling initialize().
        vm.prank(users.owner);
        assetModule.initialize();

        // Then : The Asset Module should be added to the Registry as an asset.
        assertTrue(registry.inRegistry(address(assetModule)));

        // And : The assetModule is added to itself as an asset.
        assertTrue(assetModule.inAssetModule(address(assetModule)));
    }
}
