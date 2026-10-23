/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";
import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "WrappedAerodromeAM".
 */
contract Initialize_WrappedAerodromeAM_Fuzz_Test is WrappedAerodromeAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        WrappedAerodromeAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_Revert_initialize_NotOwner(address unprivilegedAddress) public {
        // Given: The unprivileged address is not the owner of the Asset Module.
        vm.assume(unprivilegedAddress != users.owner);

        // And: An Asset Module is deployed.
        vm.prank(users.owner);
        WrappedAerodromeAM assetModule = new WrappedAerodromeAM(users.owner, address(registry));

        // When: Initialize is called.
        // Then: It reverts.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
    }

    function testFuzz_Success_initialize() public {
        // Given: An Asset Module is deployed.
        vm.prank(users.owner);
        WrappedAerodromeAM assetModule = new WrappedAerodromeAM(users.owner, address(registry));

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
