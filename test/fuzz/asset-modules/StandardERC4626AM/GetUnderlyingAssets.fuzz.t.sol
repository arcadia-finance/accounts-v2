/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StandardERC4626AM_Fuzz_Test } from "./_StandardERC4626AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "StandardERC4626AM".
 */
contract GetUnderlyingAssets_StandardERC4626AM_Fuzz_Test is StandardERC4626AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StandardERC4626AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssets_InAssetModule() public {
        vm.prank(users.creatorAddress);
        erc4626AM.addAsset(address(ybToken1));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(ybToken1)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](1);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));

        bytes32[] memory actualUnderlyingAssetKeys = erc4626AM.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule() public {
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(ybToken1)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](1);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));

        bytes32[] memory actualUnderlyingAssetKeys = erc4626AM.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
    }
}
