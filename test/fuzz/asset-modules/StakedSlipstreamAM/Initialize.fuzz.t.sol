/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

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

    function testFuzz_Revert_initialize_NotOwner(address unprivilegedAddress, address assetModuleOwner) public {
        // Given: An Asset Module.
        vm.prank(users.owner);
        StakedSlipstreamAM assetModule = new StakedSlipstreamAM(
            assetModuleOwner,
            address(registry),
            address(slipstreamPositionManager),
            address(voter),
            AERO,
            users.treasury
        );

        // And: The unprivileged address is not the owner of the Asset Module.
        vm.assume(unprivilegedAddress != assetModuleOwner);

        // When: The unprivileged address initializes the Asset Module.
        // Then: It reverts.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
    }

    function testFuzz_Revert_initialize_RewardTokenNotAllowed(address assetModuleOwner) public {
        // Given: The reward token has no Asset Module in the Registry.
        registry.setAssetModule(AERO, address(0));

        // And: An Asset Module.
        vm.prank(users.owner);
        StakedSlipstreamAM assetModule = new StakedSlipstreamAM(
            assetModuleOwner,
            address(registry),
            address(slipstreamPositionManager),
            address(voter),
            AERO,
            users.treasury
        );

        // When: The owner initializes the Asset Module.
        // Then: It reverts.
        vm.prank(assetModuleOwner);
        vm.expectRevert(StakedSlipstreamAM.RewardTokenNotAllowed.selector);
        assetModule.initialize();
    }

    function testFuzz_Revert_initialize_AlreadyInitialized(address assetModuleOwner) public {
        // Given: An Asset Module.
        vm.prank(users.owner);
        StakedSlipstreamAM assetModule = new StakedSlipstreamAM(
            assetModuleOwner,
            address(registry),
            address(slipstreamPositionManager),
            address(voter),
            AERO,
            users.treasury
        );

        // And: The Asset Module is added to the Registry.
        vm.prank(users.owner);
        registry.addAssetModule(address(assetModule));

        // And: The Asset Module is already initialized.
        vm.prank(assetModuleOwner);
        assetModule.initialize();

        // When: The owner initializes the Asset Module again.
        // Then: It reverts.
        vm.prank(assetModuleOwner);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        assetModule.initialize();
    }

    function testFuzz_Success_initialize(address assetModuleOwner) public {
        // Given: An Asset Module.
        vm.prank(users.owner);
        StakedSlipstreamAM assetModule = new StakedSlipstreamAM(
            assetModuleOwner,
            address(registry),
            address(slipstreamPositionManager),
            address(voter),
            AERO,
            users.treasury
        );

        // And: The Asset Module is added to the Registry.
        vm.prank(users.owner);
        registry.addAssetModule(address(assetModule));

        // When: The owner initializes the Asset Module.
        vm.prank(assetModuleOwner);
        assetModule.initialize();

        // Then: The Asset Module is an asset in the Registry.
        assertTrue(registry.inRegistry(address(assetModule)));

        // And: The Asset Module is an asset of itself.
        assertTrue(assetModule.inAssetModule(address(assetModule)));
    }
}
