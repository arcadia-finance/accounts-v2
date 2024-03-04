/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC4626AM_Fuzz_Test, AssetModule, StandardERC4626AM } from "./_StandardERC4626AM.fuzz.t.sol";

import { ERC4626Mock } from "../../../utils/mocks/tokens/ERC4626Mock.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "StandardERC4626AM".
 */
contract AddAsset_StandardERC4626AM_Fuzz_Test is StandardERC4626AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        erc4626AM.addAsset(asset);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_UnderlyingAssetNotAllowed() public {
        vm.prank(users.tokenCreatorAddress);
        ERC4626Mock ybToken3 = new ERC4626Mock(mockERC20.token3, "Mocked Yield Bearing Token 3", "mybTOKEN1");

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(StandardERC4626AM.Underlying_Asset_Not_Allowed.selector);
        erc4626AM.addAsset(address(ybToken3));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        erc4626AM.addAsset(address(ybToken1));
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        erc4626AM.addAsset(address(ybToken1));
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset() public {
        vm.prank(users.creatorAddress);
        erc4626AM.addAsset(address(ybToken1));

        assertTrue(registryExtension.inRegistry(address(ybToken1)));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(ybToken1)));
        bytes32[] memory underlyingAssetKeys = erc4626AM.getUnderlyingAssets(assetKey);

        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
        assertTrue(erc4626AM.inAssetModule(address(ybToken1)));
    }
}
