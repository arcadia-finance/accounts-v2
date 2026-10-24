/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import {
    INonfungiblePositionManagerExtension
} from "../../../utils/fixtures/slipstream/extensions/interfaces/INonfungiblePositionManagerExtension.sol";
import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "Metadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract IsAllowed_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();

        deployMetadex03CLAM(address(metadex03PositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative_UnknownAsset(address asset, uint256 assetId) public view {
        // Given: The asset is not the NonfungiblePositionManager.
        vm.assume(asset != address(metadex03PositionManager));

        // When: The asset is checked.
        bool allowed = metadex03CLAM.isAllowed(asset, assetId);

        // Then: It is not allowed.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_Negative_UnknownId(uint256 assetId) public view {
        // Given: No position with that id is minted.

        // When: The position is checked.
        bool allowed = metadex03CLAM.isAllowed(address(metadex03PositionManager), assetId);

        // Then: It is not allowed.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_Negative_NonAllowedUnderlyingAsset(
        address lp,
        uint128 liquidity,
        int24 tickCurrent,
        int24 tickLower,
        int24 tickUpper
    ) public {
        // Given: An initialised pool of token1 and token4, of which token4 is not an allowed asset.
        (ERC20 tokenA, ERC20 tokenB) = address(mockERC20.token1) < address(mockERC20.token4)
            ? (ERC20(address(mockERC20.token1)), ERC20(address(mockERC20.token4)))
            : (ERC20(address(mockERC20.token4)), ERC20(address(mockERC20.token1)));
        tickCurrent = int24(bound(tickCurrent, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        ICLPoolExtension pool = ICLPoolExtension(
            metadex03CLFactory.createPool(address(tokenA), address(tokenB), 1, TickMath.getSqrtRatioAtTick(tickCurrent))
        );

        // And: A valid liquidity position in that pool, held by an arbitrary owner.
        vm.assume(lp != address(0));
        vm.assume(lp != address(pool));
        tickLower = int24(bound(tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        tickUpper = int24(bound(tickUpper, tickLower + 1, TickMath.MAX_TICK));
        liquidity = uint128(bound(liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(pool, liquidity, lp, tickLower, tickUpper, false);

        // When: The position is checked.
        bool allowed = metadex03CLAM.isAllowed(address(metadex03PositionManager), tokenId);

        // Then: It is not allowed.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_Negative_ZeroLiquidity(
        address lp,
        uint112 maxExposureA,
        uint112 maxExposureB,
        uint128 liquidity,
        int24 tickCurrent,
        int24 tickLower,
        int24 tickUpper
    ) public {
        // Given: An initialised pool of the allowed assets token1 and token2.
        (ERC20 tokenA, ERC20 tokenB) = address(mockERC20.token1) < address(mockERC20.token2)
            ? (ERC20(address(mockERC20.token1)), ERC20(address(mockERC20.token2)))
            : (ERC20(address(mockERC20.token2)), ERC20(address(mockERC20.token1)));
        tickCurrent = int24(bound(tickCurrent, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        ICLPoolExtension pool = ICLPoolExtension(
            metadex03CLFactory.createPool(address(tokenA), address(tokenB), 1, TickMath.getSqrtRatioAtTick(tickCurrent))
        );

        // And: Both underlying assets have an arbitrary maximum exposure.
        erc20AM.setExposure(address(creditorUsd), address(tokenA), 0, maxExposureA);
        erc20AM.setExposure(address(creditorUsd), address(tokenB), 0, maxExposureB);

        // And: A valid liquidity position in that pool, held by an arbitrary owner.
        vm.assume(lp != address(0));
        vm.assume(lp != address(pool));
        tickLower = int24(bound(tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        tickUpper = int24(bound(tickUpper, tickLower + 1, TickMath.MAX_TICK));
        liquidity = uint128(bound(liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(pool, liquidity, lp, tickLower, tickUpper, false);

        // And: The position has no liquidity left.
        (,,,,,,, uint128 mintedLiquidity,,,,) = metadex03PositionManager.positions(tokenId);
        vm.prank(lp);
        metadex03PositionManager.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: tokenId, liquidity: mintedLiquidity, amount0Min: 0, amount1Min: 0, deadline: type(uint256).max
            })
        );

        // When: The position is checked.
        bool allowed = metadex03CLAM.isAllowed(address(metadex03PositionManager), tokenId);

        // Then: It is not allowed.
        assertFalse(allowed);
    }

    function testFuzz_Success_isAllowed_Positive(
        address lp,
        uint112 maxExposureA,
        uint112 maxExposureB,
        uint128 liquidity,
        int24 tickCurrent,
        int24 tickLower,
        int24 tickUpper
    ) public {
        // Given: An initialised pool of the allowed assets token1 and token2.
        (ERC20 tokenA, ERC20 tokenB) = address(mockERC20.token1) < address(mockERC20.token2)
            ? (ERC20(address(mockERC20.token1)), ERC20(address(mockERC20.token2)))
            : (ERC20(address(mockERC20.token2)), ERC20(address(mockERC20.token1)));
        tickCurrent = int24(bound(tickCurrent, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        ICLPoolExtension pool = ICLPoolExtension(
            metadex03CLFactory.createPool(address(tokenA), address(tokenB), 1, TickMath.getSqrtRatioAtTick(tickCurrent))
        );

        // And: Both underlying assets have an arbitrary maximum exposure.
        erc20AM.setExposure(address(creditorUsd), address(tokenA), 0, maxExposureA);
        erc20AM.setExposure(address(creditorUsd), address(tokenB), 0, maxExposureB);

        // And: A valid liquidity position in that pool, held by an arbitrary owner.
        vm.assume(lp != address(0));
        vm.assume(lp != address(pool));
        tickLower = int24(bound(tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        tickUpper = int24(bound(tickUpper, tickLower + 1, TickMath.MAX_TICK));
        liquidity = uint128(bound(liquidity, 1, pool.maxLiquidityPerTick()));
        (uint256 tokenId,,) = addLiquidityMetadex03CL(pool, liquidity, lp, tickLower, tickUpper, false);

        // When: The position is checked.
        bool allowed = metadex03CLAM.isAllowed(address(metadex03PositionManager), tokenId);

        // Then: It is allowed.
        assertTrue(allowed);
    }
}
