/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { SlipstreamAM_Fuzz_Test } from "./_SlipstreamAM.fuzz.t.sol";
import { SlipstreamAMExtension } from "../../../utils/extensions/SlipstreamAMExtension.sol";

/**
 * @notice Fuzz tests for the function "setProtocol" of contract "SlipstreamAM".
 */
contract SetProtocol_SlipstreamAM_Fuzz_Test is SlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        SlipstreamAM_Fuzz_Test.setUp();

        deploySlipstreamAM(address(slipstreamPositionManager));
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
        slipstreamAM.setProtocol();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToReg(address owner_) public {
        // Given: An Asset Module that is not registered in the Registry.
        vm.prank(users.owner);
        slipstreamAM = new SlipstreamAMExtension(owner_, address(registry), address(slipstreamPositionManager));

        // When: The protocol is set.
        // Then: It reverts.
        vm.prank(owner_);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        slipstreamAM.setProtocol();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol(address owner_) public {
        // Given: A second registered Asset Module for the same NonfungiblePositionManager.
        vm.startPrank(users.owner);
        slipstreamAM = new SlipstreamAMExtension(owner_, address(registry), address(slipstreamPositionManager));
        registry.addAssetModule(address(slipstreamAM));
        vm.stopPrank();

        // When: The protocol is set.
        // Then: It reverts.
        vm.prank(owner_);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        slipstreamAM.setProtocol();
    }

    function testFuzz_Success_setProtocol(address owner_) public {
        // Given: A registered Asset Module for a NonfungiblePositionManager that is not in the Registry.
        vm.startPrank(users.owner);
        slipstreamAM = new SlipstreamAMExtension(owner_, address(registry), address(nonfungiblePositionManagerMock));
        registry.addAssetModule(address(slipstreamAM));
        vm.stopPrank();

        // When: The protocol is set.
        vm.prank(owner_);
        slipstreamAM.setProtocol();

        // Then: The NonfungiblePositionManager is registered in the Asset Module and in the Registry.
        assertTrue(slipstreamAM.inAssetModule(address(nonfungiblePositionManagerMock)));
        assertTrue(registry.inRegistry(address(nonfungiblePositionManagerMock)));
    }
}
