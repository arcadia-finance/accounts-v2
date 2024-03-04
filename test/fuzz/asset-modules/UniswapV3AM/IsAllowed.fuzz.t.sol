/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV3AM_Fuzz_Test } from "./_UniswapV3AM.fuzz.t.sol";

import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";

import { INonfungiblePositionManagerExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/INonfungiblePositionManagerExtension.sol";

/**
 * @notice Fuzz tests for the function "isAllowed" of contract "UniswapV3AM".
 */
contract IsAllowed_UniswapV3AM_Fuzz_Test is UniswapV3AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3AM_Fuzz_Test.setUp();

        deployUniswapV3AM(address(nonfungiblePositionManager));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_isAllowed_Negative_UnknownAsset(address asset, uint256 assetId) public {
        vm.assume(asset != address(nonfungiblePositionManager));

        assertFalse(uniV3AssetModule.isAllowed(asset, assetId));
    }

    function testFuzz_Success_isAllowed_Negative_UnknownId(uint256 assetId) public {
        assertFalse(uniV3AssetModule.isAllowed(address(nonfungiblePositionManager), assetId));
    }

    function testFuzz_Success_isAllowListed_Negative_NonAllowedUnderlyingAsset(address lp) public {
        vm.assume(lp != address(0));

        // Create a LP-position of two underlying assets: token1 and token4.
        // Token 4 has no exposure set
        ERC20 tokenA = ERC20(address(mockERC20.token1));
        ERC20 tokenB = ERC20(address(mockERC20.token4));
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pool = nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(tokenA), address(tokenB), 100, 1 << 96
        );

        vm.assume(lp != pool);

        deal(address(tokenA), lp, 1e8);
        deal(address(tokenB), lp, 1e8);
        vm.startPrank(lp);
        tokenA.approve(address(nonfungiblePositionManager), type(uint256).max);
        tokenB.approve(address(nonfungiblePositionManager), type(uint256).max);
        (uint256 tokenId,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: address(tokenA),
                token1: address(tokenB),
                fee: 100,
                tickLower: -1,
                tickUpper: 1,
                amount0Desired: 1e8,
                amount1Desired: 1e8,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();

        // No maxExposures for tokenA and tokenB are set.
        assertFalse(uniV3AssetModule.isAllowed(address(nonfungiblePositionManager), tokenId));
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
        address pool = nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(tokenA), address(tokenB), 100, 1 << 96
        );

        vm.assume(lp != pool);

        deal(address(tokenA), lp, 1e8);
        deal(address(tokenB), lp, 1e8);
        vm.startPrank(lp);
        tokenA.approve(address(nonfungiblePositionManager), type(uint256).max);
        tokenB.approve(address(nonfungiblePositionManager), type(uint256).max);
        (uint256 tokenId,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: address(tokenA),
                token1: address(tokenB),
                fee: 100,
                tickLower: -1,
                tickUpper: 1,
                amount0Desired: 1e8,
                amount1Desired: 1e8,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: type(uint256).max
            })
        );

        // Set liquidity to 0
        (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);
        nonfungiblePositionManager.decreaseLiquidity(
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

        // Test that Uni V3 LP token with allowed exposure to the underlying assets but with 0 liquidity is not allowed.
        assertFalse(uniV3AssetModule.isAllowed(address(nonfungiblePositionManager), tokenId));
    }

    function testFuzz_Success_isAllowed_Positive(address lp, uint128 maxExposureA, uint128 maxExposureB) public {
        vm.assume(lp != address(0));
        vm.assume(maxExposureA > 0);
        vm.assume(maxExposureB > 0);

        // Create a LP-position of two underlying assets: token1 and token2.
        ERC20 tokenA = ERC20(address(mockERC20.token1));
        ERC20 tokenB = ERC20(address(mockERC20.token2));
        (tokenA, tokenB) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        address pool = nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(tokenA), address(tokenB), 100, 1 << 96
        );

        vm.assume(lp != pool);

        deal(address(tokenA), lp, 1e8);
        deal(address(tokenB), lp, 1e8);
        vm.startPrank(lp);
        tokenA.approve(address(nonfungiblePositionManager), type(uint256).max);
        tokenB.approve(address(nonfungiblePositionManager), type(uint256).max);
        (uint256 tokenId,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManagerExtension.MintParams({
                token0: address(tokenA),
                token1: address(tokenB),
                fee: 100,
                tickLower: -1,
                tickUpper: 1,
                amount0Desired: 1e8,
                amount1Desired: 1e8,
                amount0Min: 0,
                amount1Min: 0,
                recipient: lp,
                deadline: type(uint256).max
            })
        );
        vm.stopPrank();

        // Exposures are greater than 0 for both token 1 and token 2, see Fuzz.t.sol

        // Test that Uni V3 LP token with allowed exposure to the underlying assets is allowlisted.
        assertTrue(uniV3AssetModule.isAllowed(address(nonfungiblePositionManager), tokenId));
    }
}
