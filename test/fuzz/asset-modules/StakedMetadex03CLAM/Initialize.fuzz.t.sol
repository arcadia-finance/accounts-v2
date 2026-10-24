/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { StakedMetadex03CLAM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03CLAM.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "StakedMetadex03CLAM".
 */
contract Initialize_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_initialize_NotOwner(
        address unprivilegedAddress,
        address assetModuleOwner,
        address recipient
    ) public {
        // Given: An Asset Module with a non zero recipient of the deferred emissions.
        vm.assume(recipient != address(0));
        vm.prank(users.owner);
        StakedMetadex03CLAM assetModule = new StakedMetadex03CLAM(
            assetModuleOwner, address(registry), address(metadex03CLGaugeFactory), rewardToken, recipient
        );

        // And: The unprivileged address is not the owner of the Asset Module.
        vm.assume(unprivilegedAddress != assetModuleOwner);

        // When: The unprivileged address initializes the Asset Module.
        // Then: It reverts.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
    }

    function testFuzz_Revert_initialize_RewardTokenNotAllowed(address assetModuleOwner, address recipient) public {
        // Given: The ReceiptToken has no Asset Module in the Registry.
        registry.setAssetModule(receiptToken, address(0));

        // And: An Asset Module with a non zero recipient of the deferred emissions.
        vm.assume(recipient != address(0));
        vm.prank(users.owner);
        StakedMetadex03CLAM assetModule = new StakedMetadex03CLAM(
            assetModuleOwner, address(registry), address(metadex03CLGaugeFactory), rewardToken, recipient
        );

        // When: The owner initializes the Asset Module.
        // Then: It reverts.
        vm.prank(assetModuleOwner);
        vm.expectRevert(StakedSlipstreamAM.RewardTokenNotAllowed.selector);
        assetModule.initialize();
    }

    function testFuzz_Revert_initialize_AlreadyInitialized(address assetModuleOwner, address recipient) public {
        // Given: An Asset Module with a non zero recipient of the deferred emissions.
        vm.assume(recipient != address(0));
        vm.prank(users.owner);
        StakedMetadex03CLAM assetModule = new StakedMetadex03CLAM(
            assetModuleOwner, address(registry), address(metadex03CLGaugeFactory), rewardToken, recipient
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

    function testFuzz_Success_initialize(address assetModuleOwner, address recipient) public {
        // Given: An Asset Module with a non zero recipient of the deferred emissions.
        vm.assume(recipient != address(0));
        vm.prank(users.owner);
        StakedMetadex03CLAM assetModule = new StakedMetadex03CLAM(
            assetModuleOwner, address(registry), address(metadex03CLGaugeFactory), rewardToken, recipient
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
