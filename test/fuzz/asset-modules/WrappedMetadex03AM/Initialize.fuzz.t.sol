/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedMetadex03AM } from "../../../../src/asset-modules/Metadex03/WrappedMetadex03AM.sol";
import { WrappedMetadex03AM_Fuzz_Test } from "./_WrappedMetadex03AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "WrappedMetadex03AM".
 */
contract Initialize_WrappedMetadex03AM_Fuzz_Test is WrappedMetadex03AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedMetadex03AM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_initialize_NotOwner(address unprivilegedAddress) public {
        // Given: The unprivileged address is not the owner of the Asset Module.
        vm.assume(unprivilegedAddress != users.owner);

        // And: An Asset Module is deployed.
        vm.prank(users.owner);
        WrappedMetadex03AM assetModule = new WrappedMetadex03AM(users.owner, address(registry));

        // When: Initialize is called.
        // Then: It reverts.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
    }

    function testFuzz_Success_initialize() public {
        // Given: An Asset Module is deployed.
        vm.prank(users.owner);
        WrappedMetadex03AM assetModule = new WrappedMetadex03AM(users.owner, address(registry));

        // And: The Asset Module is added to the Registry.
        vm.prank(users.owner);
        registry.addAssetModule(address(assetModule));

        // When: Initialize is called.
        vm.prank(users.owner);
        assetModule.initialize();

        // Then: The Asset Module is added to the Registry as an asset.
        assertTrue(registry.inRegistry(address(assetModule)));

        // And: The Asset Module holds itself as an asset.
        assertTrue(assetModule.inAssetModule(address(assetModule)));
    }
}
