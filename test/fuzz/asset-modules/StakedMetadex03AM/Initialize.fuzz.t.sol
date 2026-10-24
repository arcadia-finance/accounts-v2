/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { StakedMetadex03AM } from "../../../../src/asset-modules/Metadex03/StakedMetadex03AM.sol";
import { StakedMetadex03AM_Fuzz_Test } from "./_StakedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "StakedMetadex03AM".
 */
contract Initialize_StakedMetadex03AM_Fuzz_Test is StakedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StakedMetadex03AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_initialize_NotOwner(address owner_, address unprivilegedAddress) public {
        // Given: The unprivileged address is not the owner of the Asset Module.
        vm.assume(unprivilegedAddress != owner_);

        // And: Asset Module is deployed.
        vm.prank(users.owner);
        StakedMetadex03AM assetModule = new StakedMetadex03AM(
            owner_,
            address(registry),
            address(metadex03StableGaugeFactory),
            address(metadex03GaugeFactory),
            surplusRecipient
        );

        // When: Calling initialize().
        // Then: It should revert.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
    }

    function testFuzz_Revert_initialize_RewardTokenNotAllowed(address owner_) public {
        // Given: No Asset Module is set for the Reward Token.
        registry.setAssetModule(receiptToken, address(0));

        // And: Asset Module is deployed.
        vm.prank(users.owner);
        StakedMetadex03AM assetModule = new StakedMetadex03AM(
            owner_,
            address(registry),
            address(metadex03StableGaugeFactory),
            address(metadex03GaugeFactory),
            surplusRecipient
        );

        // When: Calling initialize().
        // Then: It should revert.
        vm.prank(owner_);
        vm.expectRevert(StakedMetadex03AM.RewardTokenNotAllowed.selector);
        assetModule.initialize();
    }

    function testFuzz_Revert_initialize_AlreadyInitialized(address owner_) public {
        // Given: Asset Module is deployed.
        vm.prank(users.owner);
        StakedMetadex03AM assetModule = new StakedMetadex03AM(
            owner_,
            address(registry),
            address(metadex03StableGaugeFactory),
            address(metadex03GaugeFactory),
            surplusRecipient
        );

        // And: Asset Module is added to the Registry.
        vm.prank(users.owner);
        registry.addAssetModule(address(assetModule));

        // And: Asset Module is Initialized.
        vm.prank(owner_);
        assetModule.initialize();

        // When: Calling initialize().
        // Then: It should revert.
        vm.prank(owner_);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        assetModule.initialize();
    }

    function testFuzz_Success_initialize(address owner_) public {
        // Given: Asset Module is deployed.
        vm.prank(users.owner);
        StakedMetadex03AM assetModule = new StakedMetadex03AM(
            owner_,
            address(registry),
            address(metadex03StableGaugeFactory),
            address(metadex03GaugeFactory),
            surplusRecipient
        );

        // And: Asset Module is added to the Registry.
        vm.prank(users.owner);
        registry.addAssetModule(address(assetModule));

        // When: Calling initialize().
        vm.prank(owner_);
        assetModule.initialize();

        // Then: The Asset Module should be added to the Registry as an asset.
        assertTrue(registry.inRegistry(address(assetModule)));

        // And: The assetModule is added to itself as an asset.
        assertTrue(assetModule.inAssetModule(address(assetModule)));
    }
}
