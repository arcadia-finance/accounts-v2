/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { UniswapV3AM_Fuzz_Test } from "./_UniswapV3AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "UniswapV3AM".
 */
contract GetUnderlyingAssets_UniswapV3AM_Fuzz_Test is UniswapV3AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    uint256 internal id;
    address token0;
    address token1;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3AM_Fuzz_Test.setUp();

        (id,,) = addLiquidityUniV3(poolStable1Stable2, 100, 100, users.liquidityProvider, 0, 1, true);
        (token0, token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        deployUniswapV3AM(address(nonfungiblePositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssets_InAssetModule() public {
        vm.prank(users.owner);
        uniV3AM.addAsset(id);

        bytes32 assetKey = bytes32(abi.encodePacked(uint96(id), address(nonfungiblePositionManagerMock)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), token0));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), token1));

        bytes32[] memory actualUnderlyingAssetKeys = uniV3AM.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule() public view {
        bytes32 assetKey = bytes32(abi.encodePacked(uint96(id), address(nonfungiblePositionManagerMock)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), token0));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), token1));

        bytes32[] memory actualUnderlyingAssetKeys = uniV3AM.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }
}
