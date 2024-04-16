/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { AbstractWrappedAM_Fuzz_Test, WrappedAM } from "./_AbstractWrappedAM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "WrappedAM".
 */
contract Initialize_AbstractWrappedAM_Fuzz_Test is AbstractWrappedAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        AbstractWrappedAM_Fuzz_Test.setUp();
    }

    /* ///////////////////////////////////////////////////////////////
                              TESTS
    /////////////////////////////////////////////////////////////// */

    function testFuzz_revert_initialize_NotOwner(uint8 maxRewards, address random) public {
        // Given : Caller is not the owner
        vm.assume(random != users.creatorAddress);

        vm.startPrank(random);

        // When : calling initialize()
        vm.expectRevert("UNAUTHORIZED");
        wrappedAM.initialize(maxRewards);

        vm.stopPrank();
    }

    function testFuzz_success_initialize(uint8 maxRewards) public {
        // Given : Asset Module is added to the Registry.
        vm.startPrank(users.creatorAddress);
        registryExtension.addAssetModule(address(wrappedAM));

        // When : calling initialize()
        wrappedAM.initialize(maxRewards);

        // Then : wrappedAM should be added to the registry and AM itself
        assertEq(wrappedAM.inAssetModule(address(wrappedAM)), true);
        assertEq(registryExtension.inRegistry(address(wrappedAM)), true);

        // And : maxRewards should be set
        assertEq(wrappedAM.maxRewardsPerAsset(), maxRewards);
    }
}
