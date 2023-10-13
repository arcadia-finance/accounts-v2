/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Constants, StandardERC4626PricingModule_Fuzz_Test } from "./_StandardERC4626PricingModule.fuzz.t.sol";

import { ERC4626Mock } from "../../.././utils/mocks/ERC4626Mock.sol";

/**
 * @notice Fuzz tests for the "addAsset" of contract "StandardERC4626PricingModule".
 */
contract AddAsset_StandardERC4626PricingModule_Fuzz_Test is StandardERC4626PricingModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626PricingModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        erc4626PricingModule.addAsset(asset);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_Token0NotAllowed() public {
        vm.prank(users.tokenCreatorAddress);
        ERC4626Mock ybToken3 = new ERC4626Mock(mockERC20.token3, "Mocked Yield Bearing Token 3", "mybTOKEN1");

        vm.startPrank(users.creatorAddress);
        vm.expectRevert("PM4626_AA: Underlying Asset not allowed");
        erc4626PricingModule.addAsset(address(ybToken3));
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(users.creatorAddress);
        erc4626PricingModule.addAsset(address(ybToken1));
        vm.expectRevert("MR_AA: Asset already in mainreg");
        erc4626PricingModule.addAsset(address(ybToken1));
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset() public {
        vm.startPrank(users.creatorAddress);
        erc4626PricingModule.addAsset(address(ybToken1));
        vm.stopPrank();

        assertTrue(mainRegistryExtension.inMainRegistry(address(ybToken1)));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(ybToken1)));
        bytes32[] memory underlyingAssetKeys = erc4626PricingModule.getUnderlyingAssets(assetKey);

        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1))));
    }
}
