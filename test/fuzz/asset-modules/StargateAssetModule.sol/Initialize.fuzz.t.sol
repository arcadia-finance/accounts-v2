/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StargateAssetModule_Fuzz_Test, StargateAssetModule } from "./_StargateAssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "initialize" of contract "StargateAssetModule".
 */
contract Initialize_StargateAssetModule_Fuzz_Test is StargateAssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override {
        StargateAssetModule_Fuzz_Test.setUp();
    }

    function testFuzz_revert_initialize_NotOwner(address lpStaking, address _unprivilegedAddress) public {
        vm.prank(users.creatorAddress);
        StargateAssetModule assetModule = new StargateAssetModule(address(registryExtension), lpStaking);

        // Given : unprivileged address is not the owner of the AM.
        vm.assume(_unprivilegedAddress != users.creatorAddress);

        // When : Calling initialize().
        // Then : It should revert.
        vm.startPrank(_unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        assetModule.initialize();
        vm.stopPrank();
    }

    function testFuzz_success_initialize(address lpStaking) public {
        StargateAssetModule assetModule = new StargateAssetModule(address(registryExtension), lpStaking);

        // Given : Asset Module is added to the Registry.
        vm.prank(users.creatorAddress);
        registryExtension.addAssetModule(address(assetModule));

        // When : Calling initialize().
        assetModule.initialize();

        // Then : The Asset Module should be added to the Registry as an asset.
        registryExtension.inRegistry(address(assetModule));
    }
}
