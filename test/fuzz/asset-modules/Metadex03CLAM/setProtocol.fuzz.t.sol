/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { Metadex03CLAMExtension } from "../../../utils/extensions/Metadex03CLAMExtension.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "setProtocol" of contract "Metadex03CLAM".
 */
contract SetProtocol_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();

        deployMetadex03CLAM(address(metadex03PositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setProtocol_NonOwner(address unprivilegedAddress_) public {
        // Given: The caller is not the owner of the Asset Module.
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.prank(unprivilegedAddress_);

        // When: The protocol is set.
        // Then: It reverts.
        vm.expectRevert("UNAUTHORIZED");
        metadex03CLAM.setProtocol();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToReg(address owner_) public {
        // Given: An Asset Module that is not registered in the Registry.
        vm.prank(users.owner);
        metadex03CLAM = new Metadex03CLAMExtension(owner_, address(registry), address(metadex03PositionManager));

        // When: The protocol is set.
        // Then: It reverts.
        vm.prank(owner_);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        metadex03CLAM.setProtocol();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol(address owner_) public {
        // Given: A second registered Asset Module for the same NonfungiblePositionManager.
        vm.startPrank(users.owner);
        metadex03CLAM = new Metadex03CLAMExtension(owner_, address(registry), address(metadex03PositionManager));
        registry.addAssetModule(address(metadex03CLAM));
        vm.stopPrank();

        // When: The protocol is set.
        // Then: It reverts.
        vm.prank(owner_);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        metadex03CLAM.setProtocol();
    }

    function testFuzz_Success_setProtocol(address owner_) public {
        // Given: A registered Asset Module for a NonfungiblePositionManager that is not in the Registry.
        vm.startPrank(users.owner);
        metadex03CLAM = new Metadex03CLAMExtension(owner_, address(registry), address(nonfungiblePositionManagerMock));
        registry.addAssetModule(address(metadex03CLAM));
        vm.stopPrank();

        // When: The protocol is set.
        vm.prank(owner_);
        metadex03CLAM.setProtocol();

        // Then: The NonfungiblePositionManager is registered in the Asset Module and in the Registry.
        assertTrue(metadex03CLAM.inAssetModule(address(nonfungiblePositionManagerMock)));
        assertTrue(registry.inRegistry(address(nonfungiblePositionManagerMock)));
    }
}
