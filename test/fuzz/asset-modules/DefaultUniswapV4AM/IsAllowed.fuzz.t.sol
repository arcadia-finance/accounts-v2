/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";
import { TickMath } from "../../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "DefaultUniswapV4AM".
 */
contract IsAllowed_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative_UnknownAsset(address asset, uint256 assetId) public {
        vm.assume(asset != address(positionManagerV4));

        assertFalse(uniswapV4AM.isAllowed(asset, assetId));
    }

    function testFuzz_Success_isAllowed_Negative_UnknownId(uint256 assetId) public {
        assertFalse(uniswapV4AM.isAllowed(address(positionManagerV4), assetId));
    }

    function testFuzz_Success_isAllowListed_Negative_NonAllowedHook(
        uint80 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given: Valid ticks.
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // Initializes a pool with hooks that are not allowed.
        stablePoolKey = initializePoolV4(
            address(mockERC20.stable1),
            address(mockERC20.stable2),
            TickMath.getSqrtPriceAtTick(0),
            address(unvalidHook),
            500,
            10
        );

        // And: Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManagerV4), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManagerV4.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // When: Calling isAllowed().
        // Then: It should return false.
        assertFalse(uniswapV4AM.isAllowed(address(positionManagerV4), tokenId));
    }

    function testFuzz_Success_isAllowListed_Negative_NonAllowedUnderlyingAsset(
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Creating a LP-position of two underlying assets: token1 and token4.
        // And : Token 4 is not added yet to Primary AM.
        stablePoolKey = initializePoolV4(
            address(mockERC20.token1),
            address(mockERC20.token4),
            TickMath.getSqrtPriceAtTick(0),
            address(validHook),
            500,
            10
        );

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManagerV4), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManagerV4.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // When : Calling isAllowed()
        // Then : It should return false (as Token4 not added to the Registry)
        assertFalse(uniswapV4AM.isAllowed(address(positionManagerV4), tokenId));
    }

    function testFuzz_Success_isAllowed_Negative_ZeroLiquidity(uint96 tokenId, int24 tickLower, int24 tickUpper)
        public
    {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Position is set (with 0 liquidity)
        positionManagerV4.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // Test that UniV4 lp with 0 liquidity is not allowed.
        assertFalse(uniswapV4AM.isAllowed(address(positionManagerV4), tokenId));
    }

    function testFuzz_Success_isAllowed_positive(uint96 tokenId, int24 tickLower, int24 tickUpper, uint128 liquidity)
        public
    {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManagerV4), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManagerV4.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // Test that UniV4 LP with valid underlying tokens is allowed.
        assertTrue(uniswapV4AM.isAllowed(address(positionManagerV4), tokenId));
    }
}
