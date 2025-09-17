/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { SlipstreamAM_Fuzz_Test } from "./_SlipstreamAM.fuzz.t.sol";

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
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
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        slipstreamAM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToReg() public {
        vm.prank(users.owner);
        slipstreamAM = new SlipstreamAMExtension(users.owner, address(registry), address(slipstreamPositionManager));

        vm.startPrank(users.owner);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        slipstreamAM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol() public {
        vm.startPrank(users.owner);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        slipstreamAM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Success_setProtocol() public {
        vm.startPrank(users.owner);
        slipstreamAM =
            new SlipstreamAMExtension(users.owner, address(registry), address(nonfungiblePositionManagerMock));
        registry.addAssetModule(address(slipstreamAM));
        vm.stopPrank();

        vm.prank(users.owner);
        slipstreamAM.setProtocol();

        assertTrue(slipstreamAM.inAssetModule(address(nonfungiblePositionManagerMock)));
        assertTrue(registry.inRegistry(address(nonfungiblePositionManagerMock)));
    }
}
