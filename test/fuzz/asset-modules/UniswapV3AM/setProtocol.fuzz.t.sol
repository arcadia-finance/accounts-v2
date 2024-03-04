/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV3AM_Fuzz_Test } from "./_UniswapV3AM.fuzz.t.sol";

import { UniswapV3AMExtension } from "../../../utils/Extensions.sol";

import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

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
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);

        vm.expectRevert("UNAUTHORIZED");
        uniV3AssetModule.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_ProtocolNotAddedToReg() public {
        vm.prank(users.creatorAddress);
        uniV3AssetModule = new UniswapV3AMExtension(address(registryExtension), address(nonfungiblePositionManager));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.OnlyAssetModule.selector);
        uniV3AssetModule.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Revert_setProtocol_OverwriteExistingProtocol() public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        uniV3AssetModule.setProtocol();
        vm.stopPrank();
    }

    function testFuzz_Success_setProtocol() public {
        vm.startPrank(users.creatorAddress);
        uniV3AssetModule = new UniswapV3AMExtension(address(registryExtension), address(nonfungiblePositionManagerMock));
        registryExtension.addAssetModule(address(uniV3AssetModule));
        vm.stopPrank();

        vm.prank(users.creatorAddress);
        uniV3AssetModule.setProtocol();

        assertTrue(uniV3AssetModule.inAssetModule(address(nonfungiblePositionManagerMock)));
        assertTrue(registryExtension.inRegistry(address(nonfungiblePositionManagerMock)));
    }
}
