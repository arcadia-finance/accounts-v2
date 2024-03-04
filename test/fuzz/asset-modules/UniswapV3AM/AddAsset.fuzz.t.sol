/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV3AM_Fuzz_Test, AssetModule, UniswapV3AM } from "./_UniswapV3AM.fuzz.t.sol";

import { NonfungiblePositionManagerMock } from "../../../utils/mocks/UniswapV3/NonfungiblePositionManager.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "UniswapV3AM".
 */
contract AddAsset_UniswapV3AM_Fuzz_Test is UniswapV3AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3AM_Fuzz_Test.setUp();

        deployUniswapV3AM(address(nonfungiblePositionManagerMock));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addAsset_IdTooLarge(
        uint256 tokenId,
        NonfungiblePositionManagerMock.Position memory position
    ) public {
        tokenId = bound(tokenId, uint256(type(uint96).max) + 1, type(uint256).max);

        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(UniswapV3AM.InvalidId.selector);
        uniV3AssetModule.addAsset(tokenId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_ZeroLiquidity(
        uint96 tokenId,
        NonfungiblePositionManagerMock.Position memory position
    ) public {
        // Given: position is valid.
        position = givenValidPosition(position);

        // And: Liquidity is zero (test-case).
        position.liquidity = 0;

        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(UniswapV3AM.ZeroLiquidity.selector);
        uniV3AssetModule.addAsset(tokenId);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint96 tokenId, NonfungiblePositionManagerMock.Position memory position)
        public
    {
        // Given: position is valid.
        position = givenValidPosition(position);

        // And: Liquidity is not-zero (see testFuzz_Revert_addAsset_ZeroLiquidity).
        position.liquidity = uint128(bound(position.liquidity, 1, type(uint128).max));

        nonfungiblePositionManagerMock.setPosition(address(poolStable1Stable2), tokenId, position);

        vm.prank(users.creatorAddress);
        uniV3AssetModule.addAsset(tokenId);

        assertEq(uniV3AssetModule.getAssetToLiquidity(tokenId), position.liquidity);

        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock)));
        bytes32[] memory underlyingAssetKeys = uniV3AssetModule.getUnderlyingAssets(assetKey);

        (address token0, address token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), token0)));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), token1)));
    }
}
