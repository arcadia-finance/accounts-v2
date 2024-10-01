/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4AM_Fuzz_Test } from "./_UniswapV4AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "UniswapV4AM".
 */
contract IsAllowed_UniswapV4AM_Fuzz_Test is UniswapV4AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative_UnknownAsset(address asset, uint256 assetId) public {
        vm.assume(asset != address(positionManager));

        assertFalse(uniswapV4AM.isAllowed(asset, assetId));
    }

    function testFuzz_Success_isAllowed_Negative_UnknownId(uint256 assetId) public {
        assertFalse(uniswapV4AM.isAllowed(address(positionManager), assetId));
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
        stablePoolKey = initializePool(
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
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // When : Calling isAllowed()
        // Then : It should return false (as Token4 not added to the Registry)
        assertFalse(uniswapV4AM.isAllowed(address(positionManager), tokenId));
    }

    function testFuzz_Success_isAllowed_Negative_ZeroLiquidity(uint96 tokenId, int24 tickLower, int24 tickUpper)
        public
    {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Position is set (with 0 liquidity)
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // Test that UniV4 lp with 0 liquidity is not allowed.
        assertFalse(uniswapV4AM.isAllowed(address(positionManager), tokenId));
    }

    function testFuzz_Success_isAllowed(uint96 tokenId, int24 tickLower, int24 tickUpper, uint128 liquidity) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // Test that UniV4 LP with valid underlying tokens is allowed.
        assertTrue(uniswapV4AM.isAllowed(address(positionManager), tokenId));
    }
}