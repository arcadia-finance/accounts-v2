/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { ICLPoolExtension } from "../../../utils/fixtures/slipstream/extensions/interfaces/ICLPoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { Metadex03CLAM_Fuzz_Test } from "./_Metadex03CLAM.fuzz.t.sol";
import { NonfungiblePositionManagerMock } from "../../../utils/mocks/Slipstream/NonfungiblePositionManager.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "Metadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetUnderlyingAssetsAmounts_Metadex03CLAM_Fuzz_Test is Metadex03CLAM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Metadex03CLAM_Fuzz_Test.setUp();

        deployMetadex03CLAM(address(nonfungiblePositionManagerMock));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Overflow_PriceToken0(
        uint96 tokenId,
        int24 tickCurrent,
        NonfungiblePositionManagerMock.Position memory position,
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1
    ) public {
        // Given: Two underlying tokens, sorted the way the pool sorts them.
        asset0.decimals = bound(asset0.decimals, 0, 18);
        asset1.decimals = bound(asset1.decimals, 0, 18);
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: The usd rate of token1 stays within its unit correction.
        asset1.usdValue = bound(asset1.usdValue, 1, type(uint256).max / 10 ** 18);

        // And: The usd rate of token0 is too large to convert into a relative price.
        asset0.usdValue = bound(asset0.usdValue, type(uint256).max / 10 ** (46 - asset0.decimals) + 1, INT256_MAX);

        // And: Both underlying tokens are allowed assets with that usd rate.
        addAssetToArcadia(address(token0), int256(asset0.usdValue));
        addAssetToArcadia(address(token1), int256(asset1.usdValue));

        // And: A valid position in an initialised pool of both tokens.
        position = givenValidPosition(position);
        tickCurrent = int24(bound(tickCurrent, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        ICLPoolExtension pool =
            createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);
        nonfungiblePositionManagerMock.setPosition(address(pool), tokenId, position);

        // When: The underlying asset amounts of the position are calculated.
        // Then: It reverts.
        vm.expectRevert(bytes(""));
        metadex03CLAM.getUnderlyingAssetsAmounts(
            address(creditorUsd),
            bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock))),
            1,
            new bytes32[](0)
        );
    }

    function testFuzz_Revert_getUnderlyingAssetsAmounts_Overflow_PriceToken1(
        uint96 tokenId,
        int24 tickCurrent,
        NonfungiblePositionManagerMock.Position memory position,
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1
    ) public {
        // Given: Two underlying tokens, sorted the way the pool sorts them.
        asset0.decimals = bound(asset0.decimals, 0, 18);
        asset1.decimals = bound(asset1.decimals, 0, 18);
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: The usd rate of token0 is small enough to convert into a relative price.
        asset0.usdValue = bound(asset0.usdValue, 0, type(uint256).max / 10 ** (46 - asset0.decimals));

        // And: The usd rate of token1 is too large for its unit correction.
        asset1.usdValue = bound(asset1.usdValue, type(uint256).max / 10 ** 18 + 1, INT256_MAX);

        // And: Both underlying tokens are allowed assets with that usd rate.
        addAssetToArcadia(address(token0), int256(asset0.usdValue));
        addAssetToArcadia(address(token1), int256(asset1.usdValue));

        // And: A valid position in an initialised pool of both tokens.
        position = givenValidPosition(position);
        tickCurrent = int24(bound(tickCurrent, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        ICLPoolExtension pool =
            createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);
        nonfungiblePositionManagerMock.setPosition(address(pool), tokenId, position);

        // When: The underlying asset amounts of the position are calculated.
        // Then: It reverts.
        vm.expectRevert(bytes(""));
        metadex03CLAM.getUnderlyingAssetsAmounts(
            address(creditorUsd),
            bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock))),
            1,
            new bytes32[](0)
        );
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_AmountIsZero(uint96 tokenId) public view {
        // Given: The Account holds no amount of the position.

        // When: The underlying asset amounts of the position are calculated.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) = metadex03CLAM.getUnderlyingAssetsAmounts(
            address(creditorUsd),
            bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock))),
            0,
            new bytes32[](0)
        );

        // Then: Both underlying amounts are zero and no rates are returned.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts(
        uint96 tokenId,
        int24 tickCurrent,
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1,
        NonfungiblePositionManagerMock.Position memory position
    ) public {
        // Given: Two underlying tokens, sorted the way the pool sorts them.
        asset0.decimals = bound(asset0.decimals, 0, 18);
        asset1.decimals = bound(asset1.decimals, 0, 18);
        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: Both usd rates convert into a relative price that fits a sqrtPriceX96.
        asset0.usdValue = bound(asset0.usdValue, 0, type(uint256).max / 10 ** (46 - asset0.decimals));
        asset1.usdValue = bound(asset1.usdValue, 0, type(uint256).max / 10 ** 18);
        if (asset1.usdValue > 0) {
            vm.assume(asset0.usdValue / asset1.usdValue / 10 ** asset0.decimals < 2 ** 128 / 10 ** asset1.decimals);
        }

        // And: Both underlying tokens are allowed assets with that usd rate.
        addAssetToArcadia(address(token0), int256(asset0.usdValue));
        addAssetToArcadia(address(token1), int256(asset1.usdValue));

        // And: A valid position without fees, in an initialised pool of both tokens.
        position = givenValidPosition(position);
        position.feeGrowthInside0LastX128 = 0;
        position.feeGrowthInside1LastX128 = 0;
        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;
        tickCurrent = int24(bound(tickCurrent, TickMath.MIN_TICK, TickMath.MAX_TICK - 1));
        ICLPoolExtension pool =
            createPoolMetadex03CL(address(token0), address(token1), 1, TickMath.getSqrtRatioAtTick(tickCurrent), 300);
        nonfungiblePositionManagerMock.setPosition(address(pool), tokenId, position);

        // When: The underlying asset amounts of the position are calculated.
        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = metadex03CLAM.getUnderlyingAssetsAmounts(
            address(creditorUsd),
            bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock))),
            1,
            new bytes32[](0)
        );

        // Then: Both usd rates are corrected to 18 decimals.
        uint256 expectedRate0 = asset0.usdValue * 10 ** (18 - asset0.decimals);
        uint256 expectedRate1 = asset1.usdValue * 10 ** (18 - asset1.decimals);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, expectedRate0);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, expectedRate1);

        // And: Both amounts are the position's liquidity valued at the relative price of both rates.
        (uint256 expectedAmount0, uint256 expectedAmount1) = LiquidityAmounts.getAmountsForLiquidity(
            metadex03CLAM.getSqrtPriceX96(expectedRate0, expectedRate1),
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );
        assertEq(underlyingAssetsAmounts[0], expectedAmount0);
        assertEq(underlyingAssetsAmounts[1], expectedAmount1);
    }
}
