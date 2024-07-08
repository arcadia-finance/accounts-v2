/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { SlipstreamAM_Fuzz_Test } from "./_SlipstreamAM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/slipstream/extensions/interfaces/INonfungiblePositionManagerExtension.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "SlipstreamAM".
 */
contract IsAllowed_SlipstreamAM_Fuzz_Test is SlipstreamAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        SlipstreamAM_Fuzz_Test.setUp();

        deploySlipstreamAM(address(slipstreamPositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative_UnknownAsset(address asset, uint256 assetId) public {
        vm.assume(asset != address(slipstreamPositionManager));

        assertFalse(slipstreamAM.isAllowed(asset, assetId));
    }

    function testFuzz_Success_isAllowed_Negative_UnknownId(uint256 assetId) public {
        assertFalse(slipstreamAM.isAllowed(address(slipstreamPositionManager), assetId));
    }

    function testFuzz_Success_isAllowListed_Negative_NonAllowedUnderlyingAsset(address lp) public {
        vm.assume(lp != address(0));

        // Create a LP-position of two underlying assets: token1 and token4.
        // Token 4 has no exposure set
        ERC20 tokenA = ERC20(address(mockERC20.token1));
        ERC20 tokenB = ERC20(address(mockERC20.token4));
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pool = cLFactory.createPool(address(tokenA), address(tokenB), 1, 1 << 96);

        vm.assume(lp != pool);

        deal(address(tokenA), lp, 1e8);
        deal(address(tokenB), lp, 1e8);
        vm.startPrank(lp);
        tokenA.approve(address(slipstreamPositionManager), type(uint256).max);
        tokenB.approve(address(slipstreamPositionManager), type(uint256).max);
        (uint256 tokenId,,,) = slipstreamPositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: address(tokenA),
                token1: address(tokenB),
                tickSpacing: 1,
                tickLower: -1,
                tickUpper: 1,
                amount0Desired: 1e8,
                amount1Desired: 1e8,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: type(uint256).max,
                sqrtPriceX96: 0
            })
        );
        vm.stopPrank();

        // No maxExposures for tokenA and tokenB are set.
        assertFalse(slipstreamAM.isAllowed(address(slipstreamPositionManager), tokenId));
    }

    function testFuzz_Success_isAllowed_Negative_ZeroLiquidity(address lp, uint128 maxExposureA, uint128 maxExposureB)
        public
    {
        vm.assume(lp != address(0));
        vm.assume(maxExposureA > 0);
        vm.assume(maxExposureB > 0);

        // Create a LP-position of two underlying assets: token1 and token2.
        ERC20 tokenA = ERC20(address(mockERC20.token1));
        ERC20 tokenB = ERC20(address(mockERC20.token2));
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pool = cLFactory.createPool(address(tokenA), address(tokenB), 1, 1 << 96);

        vm.assume(lp != pool);

        deal(address(tokenA), lp, 1e8);
        deal(address(tokenB), lp, 1e8);
        vm.startPrank(lp);
        tokenA.approve(address(slipstreamPositionManager), type(uint256).max);
        tokenB.approve(address(slipstreamPositionManager), type(uint256).max);
        (uint256 tokenId,,,) = slipstreamPositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: address(tokenA),
                token1: address(tokenB),
                tickSpacing: 1,
                tickLower: -1,
                tickUpper: 1,
                amount0Desired: 1e8,
                amount1Desired: 1e8,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: type(uint256).max,
                sqrtPriceX96: 0
            })
        );

        // Set liquidity to 0
        (,,,,,,, uint128 liquidity,,,,) = slipstreamPositionManager.positions(tokenId);
        slipstreamPositionManager.decreaseLiquidity(
            INonfungiblePositionManagerExtension.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();

        // Exposures are greater than 0 for both token 1 and token 2, see Fuzz.t.sol

        // Test that Slipstream LP token with allowed exposure to the underlying assets but with 0 liquidity is not allowed.
        assertFalse(slipstreamAM.isAllowed(address(slipstreamPositionManager), tokenId));
    }

    function testFuzz_Success_isAllowed_Positive(address lp, uint128 maxExposureA, uint128 maxExposureB) public {
        vm.assume(lp != address(0));
        vm.assume(maxExposureA > 0);
        vm.assume(maxExposureB > 0);

        // Create a LP-position of two underlying assets: token1 and token2.
        ERC20 tokenA = ERC20(address(mockERC20.token1));
        ERC20 tokenB = ERC20(address(mockERC20.token2));
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pool = cLFactory.createPool(address(tokenA), address(tokenB), 1, 1 << 96);

        vm.assume(lp != pool);

        deal(address(tokenA), lp, 1e8);
        deal(address(tokenB), lp, 1e8);
        vm.startPrank(lp);
        tokenA.approve(address(slipstreamPositionManager), type(uint256).max);
        tokenB.approve(address(slipstreamPositionManager), type(uint256).max);
        (uint256 tokenId,,,) = slipstreamPositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: address(tokenA),
                token1: address(tokenB),
                tickSpacing: 1,
                tickLower: -1,
                tickUpper: 1,
                amount0Desired: 1e8,
                amount1Desired: 1e8,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: type(uint256).max,
                sqrtPriceX96: 0
            })
        );
        vm.stopPrank();

        // Exposures are greater than 0 for both token 1 and token 2, see Fuzz.t.sol

        // Test that Slipstream LP token with allowed exposure to the underlying assets is allowlisted.
        assertTrue(slipstreamAM.isAllowed(address(slipstreamPositionManager), tokenId));
    }
}
