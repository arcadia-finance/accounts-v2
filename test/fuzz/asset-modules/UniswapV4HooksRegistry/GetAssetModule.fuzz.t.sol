/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4HooksRegistry_Fuzz_Test } from "./_UniswapV4HooksRegistry.fuzz.t.sol";
import { UniswapV4HooksRegistry } from "../../../../src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";

/**
 * @notice Fuzz tests for the function "getAssetModule" of contract "UniswapV4HooksRegistry".
 */
contract GetAssetModule_UniswapV4HooksRegistry_Fuzz_Test is UniswapV4HooksRegistry_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4HooksRegistry_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getAssetModule_NoAM(uint96 tokenId, int24 tickLower, int24 tickUpper, uint128 liquidity)
        public
    {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And: A pool with hooks that are not allowed.
        randomPoolKey = initializePool(
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
        positionManager.setPosition(users.owner, randomPoolKey, tickLower, tickUpper, tokenId);

        // When: Calling getAssetModule()
        address assetModule = v4HooksRegistry.getAssetModule(tokenId);

        // Then: It should return the zero address.
        assertEq(assetModule, address(0));
    }

    function testFuzz_Success_getAssetModule_InvalidTokenId(uint96 tokenId) public {
        // Given : tokenId is invalid as no positions are previously minted
        // When : Calling getAssetModule()
        address assetModule = v4HooksRegistry.getAssetModule(tokenId);

        // Then : It should return the zero address
        assertEq(assetModule, address(0));
    }

    function testFuzz_Success_getAssetModule_SpecificV4AM(
        address assetModule,
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And: A pool with hooks that are not allowed.
        randomPoolKey = initializePool(
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
        positionManager.setPosition(users.owner, randomPoolKey, tickLower, tickUpper, tokenId);

        // And: Hooks is added to the Registry.
        v4HooksRegistry.setHooksToAssetModule(address(unvalidHook), assetModule);

        // When: Calling getAssetModule()
        address assetModule_ = v4HooksRegistry.getAssetModule(tokenId);

        // Then: It should return the correct asset module.
        assertEq(assetModule, assetModule_);
    }

    function testFuzz_Success_getAssetModule_DefaultV4AM(
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given : Valid ticks
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);

        // And : Liquidity is not-zero
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);

        // When: Calling getAssetModule()
        address assetModule = v4HooksRegistry.getAssetModule(tokenId);

        // Then: It should return the correct asset module.
        assertEq(assetModule, address(uniswapV4AM));
    }
}
