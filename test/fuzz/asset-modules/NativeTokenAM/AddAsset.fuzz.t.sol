/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { BitPackingLib } from "../../../../src/libraries/BitPackingLib.sol";
import { NativeTokenAM_Fuzz_Test } from "./_NativeTokenAM.fuzz.t.sol";
import { PrimaryAM } from "../../../../src/asset-modules/abstracts/AbstractPrimaryAM.sol";
import { RegistryErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "NativeTokenAM".
 */
contract AddAsset_NativeTokenAM_Fuzz_Test is NativeTokenAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        NativeTokenAM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addAsset_NonOwner(address unprivilegedAddress_, address asset) public {
        vm.assume(unprivilegedAddress_ != users.owner);
        vm.assume(asset != address(mockERC20.stable1));
        vm.assume(asset != address(mockERC20.stable2));
        vm.assume(asset != address(mockERC20.token1));
        vm.assume(asset != address(mockERC20.token2));
        vm.assume(asset != address(mockERC721.nft1));
        vm.assume(asset != address(mockERC1155.sft1));

        vm.prank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        nativeTokenAM.addAsset(asset, oraclesNativeTokenToUsd);
    }

    function testFuzz_Revert_addAsset_BadOracleSequence(address asset) public {
        vm.assume(asset != address(mockERC20.stable1));
        vm.assume(asset != address(mockERC20.stable2));
        vm.assume(asset != address(mockERC20.token1));
        vm.assume(asset != address(mockERC20.token2));
        vm.assume(asset != address(mockERC721.nft1));
        vm.assume(asset != address(mockERC1155.sft1));

        bool[] memory badDirection = new bool[](1);
        badDirection[0] = false;
        uint80[] memory oracleToken4ToUsdArr = new uint80[](1);
        oracleToken4ToUsdArr[0] = uint80(chainlinkOM.oracleToOracleId(address(mockOracles.token4ToUsd)));
        bytes32 badSequence = BitPackingLib.pack(badDirection, oracleToken4ToUsdArr);

        vm.startPrank(users.owner);
        vm.expectRevert(PrimaryAM.BadOracleSequence.selector);
        nativeTokenAM.addAsset(asset, badSequence);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_OverwriteExistingAsset(address asset) public {
        vm.assume(asset != address(mockERC20.stable1));
        vm.assume(asset != address(mockERC20.stable2));
        vm.assume(asset != address(mockERC20.token1));
        vm.assume(asset != address(mockERC20.token2));
        vm.assume(asset != address(mockERC721.nft1));
        vm.assume(asset != address(mockERC1155.sft1));

        vm.startPrank(users.owner);
        nativeTokenAM.addAsset(asset, oraclesNativeTokenToUsd);
        vm.expectRevert(RegistryErrors.AssetAlreadyInRegistry.selector);
        nativeTokenAM.addAsset(asset, oraclesNativeTokenToUsd);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(address asset) public {
        vm.assume(asset != address(mockERC20.stable1));
        vm.assume(asset != address(mockERC20.stable2));
        vm.assume(asset != address(mockERC20.token1));
        vm.assume(asset != address(mockERC20.token2));
        vm.assume(asset != address(mockERC721.nft1));
        vm.assume(asset != address(mockERC1155.sft1));

        vm.prank(users.owner);
        nativeTokenAM.addAsset(asset, oraclesNativeTokenToUsd);

        assertTrue(nativeTokenAM.inAssetModule(asset));
        assertTrue(nativeTokenAM.isAllowed(asset, 0));
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), asset));
        (uint64 assetUnit, bytes32 oracles) = nativeTokenAM.assetToInformation(assetKey);
        assertEq(assetUnit, 10 ** 18);
        assertEq(oracles, oraclesNativeTokenToUsd);

        assertTrue(registry.inRegistry(asset));
        (uint256 assetType, address assetModule) = registry.assetToAssetInformation(asset);
        assertEq(assetType, 4);
        assertEq(assetModule, address(nativeTokenAM));
    }
}
