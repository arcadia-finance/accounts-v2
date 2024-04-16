/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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

        deploySlipstreamAM(address(nonfungiblePositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setProtocol_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        slipstreamAM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToReg() public {
        vm.prank(users.creatorAddress);
        slipstreamAM = new SlipstreamAMExtension(address(registryExtension), address(nonfungiblePositionManager));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        slipstreamAM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol() public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        slipstreamAM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Success_setProtocol() public {
        vm.startPrank(users.creatorAddress);
        slipstreamAM = new SlipstreamAMExtension(address(registryExtension), address(nonfungiblePositionManagerMock));
        registryExtension.addAssetModule(address(slipstreamAM));
        vm.stopPrank();

        vm.prank(users.creatorAddress);
        slipstreamAM.setProtocol();

        assertTrue(slipstreamAM.inAssetModule(address(nonfungiblePositionManagerMock)));
        assertTrue(registryExtension.inRegistry(address(nonfungiblePositionManagerMock)));
    }
}
