/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4AM } from "../../../../src/asset-modules/UniswapV4/UniswapV4AM.sol";
import { UniswapV4AM_Fuzz_Test } from "./_UniswapV4AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "addAsset" of contract "UniswapV4AM".
 */
contract AddAsset_UniswapV4AM_Fuzz_Test is UniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_addAsset_IdTooLarge(uint256 tokenId) public {
        tokenId = bound(tokenId, uint256(type(uint96).max) + 1, type(uint256).max);

        vm.startPrank(users.owner);
        vm.expectRevert(UniswapV4AM.InvalidId.selector);
        uniswapV4AM.addAsset(tokenId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_ZeroLiquidity(uint80 tokenId, int24 tickLower, int24 tickUpper) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Position is set (with 0 liquidity)
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // When : Calling addAsset()
        // Then : It should revert
        vm.startPrank(users.owner);
        vm.expectRevert(UniswapV4AM.ZeroLiquidity.selector);
        uniswapV4AM.addAsset(tokenId);
        vm.stopPrank();
    }

    function testFuzz_Revert_addAsset_HooksNotAllowed(
        uint80 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // Initializes a pool with hooks that are not allowed
        stablePoolKey = initializePool(
            address(mockERC20.stable1),
            address(mockERC20.stable2),
            TickMath.getSqrtPriceAtTick(0),
            address(unvalidHook),
            500,
            10
        );

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // When : Calling addAsset() for a pool that has unallowed hooks
        // Then : It should revert
        vm.startPrank(users.owner);
        vm.expectRevert(UniswapV4AM.HooksNotAllowed.selector);
        uniswapV4AM.addAsset(tokenId);
        vm.stopPrank();
    }

    function testFuzz_Success_addAsset(uint96 tokenId, int24 tickLower, int24 tickUpper, uint128 liquidity) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // When : calling addAsset()
        vm.prank(users.owner);
        uniswapV4AM.addAsset(tokenId);

        // Then : It should return correct values
        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));
        bytes32[] memory underlyingAssetKeys = uniswapV4AM.getUnderlyingAssets(assetKey);

        (address token0, address token1) = address(mockERC20.stable1) < address(mockERC20.stable2)
            ? (address(mockERC20.stable1), address(mockERC20.stable2))
            : (address(mockERC20.stable2), address(mockERC20.stable1));

        assertEq(underlyingAssetKeys[0], bytes32(abi.encodePacked(uint96(0), token0)));
        assertEq(underlyingAssetKeys[1], bytes32(abi.encodePacked(uint96(0), token1)));
    }
}
