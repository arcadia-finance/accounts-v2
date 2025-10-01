/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { UniswapV3AM_Fuzz_Test } from "./_UniswapV3AM.fuzz.t.sol";

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";
import { UniswapV3AMExtension } from "../../../utils/extensions/UniswapV3AMExtension.sol";

/**
 * @notice Fuzz tests for the function "setProtocol" of contract "UniswapV3AM".
 */
contract SetProtocol_UniswapV3AM_Fuzz_Test is UniswapV3AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3AM_Fuzz_Test.setUp();

        deployUniswapV3AM(address(nonfungiblePositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setProtocol_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        uniV3AM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToReg() public {
        vm.prank(users.owner);
        uniV3AM = new UniswapV3AMExtension(users.owner, address(registry), address(nonfungiblePositionManager));

        vm.startPrank(users.owner);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        uniV3AM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol() public {
        vm.startPrank(users.owner);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        uniV3AM.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Success_setProtocol() public {
        vm.startPrank(users.owner);
        uniV3AM = new UniswapV3AMExtension(users.owner, address(registry), address(nonfungiblePositionManagerMock));
        registry.addAssetModule(address(uniV3AM));
        vm.stopPrank();

        vm.prank(users.owner);
        uniV3AM.setProtocol();

        assertTrue(uniV3AM.inAssetModule(address(nonfungiblePositionManagerMock)));
        assertTrue(registry.inRegistry(address(nonfungiblePositionManagerMock)));
    }
}
