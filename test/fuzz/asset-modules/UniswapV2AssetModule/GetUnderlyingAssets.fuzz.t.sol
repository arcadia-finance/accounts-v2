/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV2AssetModule_Fuzz_Test } from "./_UniswapV2AssetModule.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "UniswapV2AssetModule".
 */
contract GetUnderlyingAssets_UniswapV2AssetModule_Fuzz_Test is UniswapV2AssetModule_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV2AssetModule_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssets_InAssetModule() public {
        vm.prank(users.creatorAddress);
        uniswapV2AssetModule.addAsset(address(pairToken1Token2));

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pairToken1Token2)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));

        bytes32[] memory actualUnderlyingAssetKeys = uniswapV2AssetModule.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule() public {
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(0), address(pairToken1Token2)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token2)));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), address(mockERC20.token1)));

        bytes32[] memory actualUnderlyingAssetKeys = uniswapV2AssetModule.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }
}
