/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { WrappedAerodromeAM_Fuzz_Test } from "./_WrappedAerodromeAM.fuzz.t.sol";

import { WrappedAerodromeAM } from "../../../../src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

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
        // Given : unprivileged address is not the owner of the AM.
        vm.assume(unprivilegedAddress != users.owner);

        // And : Asset Module is deployed.
        vm.prank(users.owner);
        WrappedAerodromeAM assetModule = new WrappedAerodromeAM(address(registry));

        // When : Calling initialize().
        // Then : It should revert.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
    }

    function testFuzz_success_initialize() public {
        // Given : Asset Module is deployed.
        vm.prank(users.owner);
        WrappedAerodromeAM assetModule = new WrappedAerodromeAM(address(registry));

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
