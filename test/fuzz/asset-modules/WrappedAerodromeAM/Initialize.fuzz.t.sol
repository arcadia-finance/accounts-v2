/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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

    function testFuzz_revert_initialize_NotOwner(address unprivilegedAddress) public {
        // Given : unprivileged address is not the owner of the AM.
        vm.assume(unprivilegedAddress != users.creatorAddress);

        // And : Asset Module is deployed.
        vm.prank(users.creatorAddress);
        WrappedAerodromeAM assetModule = new WrappedAerodromeAM(address(registryExtension));

        // When : Calling initialize().
        // Then : It should revert.
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
    }

    function testFuzz_success_initialize() public {
        // Given : Asset Module is deployed.
        vm.prank(users.creatorAddress);
        WrappedAerodromeAM assetModule = new WrappedAerodromeAM(address(registryExtension));

        // And : Asset Module is added to the Registry.
        vm.prank(users.creatorAddress);
        registryExtension.addAssetModule(address(assetModule));

        // When : Calling initialize().
        vm.prank(users.creatorAddress);
        assetModule.initialize();

        // Then : The Asset Module should be added to the Registry as an asset.
        assertTrue(registryExtension.inRegistry(address(assetModule)));

        // And : The assetModule is added to itself as an asset.
        assertTrue(assetModule.inAssetModule(address(assetModule)));
    }
}
