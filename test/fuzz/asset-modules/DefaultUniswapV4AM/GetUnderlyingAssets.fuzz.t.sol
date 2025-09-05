/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Currency } from "../../../../lib/v4-periphery/lib/v4-core/src/types/Currency.sol";
import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssets" of contract "DefaultUniswapV4AM".
 */
contract GetUnderlyingAssets_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssets_InAssetModule(
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given : Valid ticks.
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero.
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManagerV4), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManagerV4.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // And : tokenId is added to AM.
        vm.prank(users.owner);
        uniswapV4AM.addAsset(tokenId);

        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManagerV4)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), Currency.unwrap(stablePoolKey.currency0)));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), Currency.unwrap(stablePoolKey.currency1)));

        // When : calling getUnderlyingAssets().
        bytes32[] memory actualUnderlyingAssetKeys = uniswapV4AM.getUnderlyingAssets(assetKey);

        // Then : It should return expected assetKeys
        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }

    function testFuzz_Success_getUnderlyingAssets_NotInAssetModule(
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given : Valid ticks.
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero.
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManagerV4), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManagerV4.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // And : Position is not added to the AM.
        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManagerV4)));
        bytes32[] memory expectedUnderlyingAssetKeys = new bytes32[](2);
        expectedUnderlyingAssetKeys[0] = bytes32(abi.encodePacked(uint96(0), Currency.unwrap(stablePoolKey.currency0)));
        expectedUnderlyingAssetKeys[1] = bytes32(abi.encodePacked(uint96(0), Currency.unwrap(stablePoolKey.currency1)));

        bytes32[] memory actualUnderlyingAssetKeys = uniswapV4AM.getUnderlyingAssets(assetKey);

        assertEq(actualUnderlyingAssetKeys[0], expectedUnderlyingAssetKeys[0]);
        assertEq(actualUnderlyingAssetKeys[1], expectedUnderlyingAssetKeys[1]);
    }
}
