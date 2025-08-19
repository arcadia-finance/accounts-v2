/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { TickMath } from "../../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "UniswapV4HooksRegistry".
 */
contract IsAllowed_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowListed_AMCaller_Negative_NonAllowedUnderlyingAsset(address asset, uint256 id)
        public
    {
        // Given: Asset is not allowed.
        vm.assume(!registry.isAllowed(asset, id));

        // When : Calling isAllowed()
        // Then : It should return false.
        vm.prank(address(uniswapV4AM));
        assertFalse(v4HooksRegistry.isAllowed(asset, id));
    }

    function testFuzz_Success_isAllowListed_AMCaller_Positive() public {
        // Given: Asset is allowed.
        assert(registry.isAllowed(address(mockERC20.stable1), 0));

        // When : Calling isAllowed()
        // Then : It should return true.
        vm.prank(address(uniswapV4AM));
        assertTrue(v4HooksRegistry.isAllowed(address(mockERC20.stable1), 0));
    }

    function testFuzz_Success_isAllowed_NonAMCaller_Negative_UnknownAsset(
        address caller,
        address asset,
        uint256 assetId
    ) public {
        // Given: caller is not an Asset Module.
        vm.assume(!v4HooksRegistry.isAssetModule(caller));

        vm.assume(asset != address(positionManagerV4));

        vm.prank(caller);
        assertFalse(v4HooksRegistry.isAllowed(asset, assetId));
    }

    function testFuzz_Success_isAllowed_NonAMCaller_Negative_UnknownId(address caller, uint256 assetId) public {
        // Given: caller is not an Asset Module.
        vm.assume(!v4HooksRegistry.isAssetModule(caller));

        vm.prank(caller);
        assertFalse(v4HooksRegistry.isAllowed(address(positionManagerV4), assetId));
    }

    function testFuzz_Success_isAllowListed_NonAMCaller_Negative_NonAllowedHook(
        address caller,
        uint80 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given: caller is not an Asset Module.
        vm.assume(!v4HooksRegistry.isAssetModule(caller));

        // And: Valid ticks.
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
        vm.prank(caller);
        assertFalse(v4HooksRegistry.isAllowed(address(positionManagerV4), tokenId));
    }

    function testFuzz_Success_isAllowListed_NonAMCaller_Negative_NonAllowedUnderlyingAsset(
        address caller,
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given: caller is not an Asset Module.
        vm.assume(!v4HooksRegistry.isAssetModule(caller));

        // And : Valid ticks
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
        vm.prank(caller);
        assertFalse(v4HooksRegistry.isAllowed(address(positionManagerV4), tokenId));
    }

    function testFuzz_Success_isAllowed_NonAMCaller_Negative_ZeroLiquidity(
        address caller,
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper
    ) public {
        // Given: caller is not an Asset Module.
        vm.assume(!v4HooksRegistry.isAssetModule(caller));

        // And : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Position is set (with 0 liquidity)
        positionManagerV4.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // Test that UniV4 lp with 0 liquidity is not allowed.
        vm.prank(caller);
        assertFalse(v4HooksRegistry.isAllowed(address(positionManagerV4), tokenId));
    }

    function testFuzz_Success_isAllowed_NonAMCaller_positive(
        address caller,
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given: caller is not an Asset Module.
        vm.assume(!v4HooksRegistry.isAssetModule(caller));

        // And : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManagerV4), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManagerV4.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // Test that UniV4 LP with valid underlying tokens is allowed.
        vm.prank(caller);
        assertTrue(v4HooksRegistry.isAllowed(address(positionManagerV4), tokenId));
    }
}
