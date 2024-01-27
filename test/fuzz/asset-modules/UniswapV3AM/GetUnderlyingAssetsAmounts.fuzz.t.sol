/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { UniswapV3AM_Fuzz_Test } from "./_UniswapV3AM.fuzz.t.sol";

import { Constants } from "../../../utils/Constants.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { IUniswapV3PoolExtension } from
    "../../../utils/fixtures/uniswap-v3/extensions/interfaces/IUniswapV3PoolExtension.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { NonfungiblePositionManagerMock } from "../../../utils/mocks/UniswapV3/NonfungiblePositionManager.sol";
import { AssetValuationLib, AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "UniswapV3AM".
 */
contract GetUnderlyingAssetsAmounts_UniswapV3AM_Fuzz_Test is UniswapV3AM_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV3AM_Fuzz_Test.setUp();

        deployUniswapV3AM(address(nonfungiblePositionManagerMock));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_GetUnderlyingAssetsAmounts_Overflow_PriceToken0(
        uint96 tokenId,
        NonfungiblePositionManagerMock.Position memory position,
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1
    ) public {
        // Given: underlying asset decimals are equal or less than 18.
        asset0.decimals = bound(asset0.decimals, 0, 18);
        asset1.decimals = bound(asset1.decimals, 0, 18);

        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: "rateUnderlyingAssetsToUsd" for token0 overflows in "_getRateUnderlyingAssetsToUsd" (test-case).
        // Or: "priceXd18" overflows in "_getSqrtPriceX96" (test-case).
        // And: "usdValue" for token0 does not overflow on cast to int256.
        if (asset1.usdValue > 0) {
            asset0.usdValue = bound(asset0.usdValue, type(uint256).max / 10 ** (54 - asset0.decimals) + 1, INT256_MAX);
        } else {
            asset0.usdValue = bound(asset0.usdValue, type(uint256).max / 10 ** 36 + 1, INT256_MAX);
        }

        // And: "rateUnderlyingAssetsToUsd" for token1 does not overflows in "_getRateUnderlyingAssetsToUsd".
        asset1.usdValue = bound(asset1.usdValue, 0, type(uint256).max / 10 ** 36);

        // And: position is valid.
        position = givenValidPosition(position);

        // And: State is persisted.
        addUnderlyingTokenToArcadia(address(token0), int256(asset0.usdValue));
        addUnderlyingTokenToArcadia(address(token1), int256(asset1.usdValue));
        IUniswapV3PoolExtension pool = createPool(token0, token1, 1e18, 300);
        nonfungiblePositionManagerMock.setPosition(address(pool), tokenId, position);

        // When: "getUnderlyingAssetsAmounts" is called.
        // Then: The transaction overflows.
        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock)));
        vm.expectRevert(bytes(""));
        uniV3AssetModule.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
    }

    function testFuzz_Revert_GetUnderlyingAssetsAmounts_Overflow_PriceToken1(
        uint96 tokenId,
        NonfungiblePositionManagerMock.Position memory position,
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1
    ) public {
        // Given: underlying asset decimals are equal or less than 18.
        asset0.decimals = bound(asset0.decimals, 0, 18);
        asset1.decimals = bound(asset1.decimals, 0, 18);

        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: "priceXd18" does not overflow in "_getSqrtPriceX96".
        asset0.usdValue = bound(asset0.usdValue, 0, type(uint256).max / 10 ** (54 - asset0.decimals));

        // And: "rateUnderlyingAssetsToUsd" for token1 overflows in "_getRateUnderlyingAssetsToUsd" (test-case).
        // And: "usdValue" for token1 does not overflow on cast to int256.
        asset1.usdValue = bound(asset1.usdValue, type(uint256).max / 10 ** 36 + 1, INT256_MAX);
        // And: "oracleRate" for token1 in "getRate" does not overflow
        asset1.usdValue = bound(
            asset1.usdValue,
            type(uint256).max / 10 ** 36 + 1,
            type(uint256).max / 10 ** (18 - Constants.tokenOracleDecimals)
        );

        // And: position is valid.
        position = givenValidPosition(position);

        // And: State is persisted.
        addUnderlyingTokenToArcadia(address(token0), int256(asset0.usdValue));
        addUnderlyingTokenToArcadia(address(token1), int256(asset1.usdValue));
        IUniswapV3PoolExtension pool = createPool(token0, token1, 1e18, 300);
        nonfungiblePositionManagerMock.setPosition(address(pool), tokenId, position);

        // When: "getUnderlyingAssetsAmounts" is called.
        // Then: The transaction overflows.
        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock)));
        vm.expectRevert(bytes(""));
        uniV3AssetModule.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
    }

    function testFuzz_Success_GetUnderlyingAssetsAmounts(
        uint96 tokenId,
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1,
        NonfungiblePositionManagerMock.Position memory position
    ) public {
        // Given: underlying asset decimals are equal or less than 18.
        asset0.decimals = bound(asset0.decimals, 0, 18);
        asset1.decimals = bound(asset1.decimals, 0, 18);

        ERC20Mock token0 = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1 = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: "priceXd18" does not overflow in "_getSqrtPriceX96".
        asset0.usdValue = bound(asset0.usdValue, 0, type(uint256).max / 10 ** (54 - asset0.decimals));

        // And: "rateUnderlyingAssetsToUsd" for token1 does not overflows in "_getRateUnderlyingAssetsToUsd".
        asset1.usdValue = bound(asset1.usdValue, 0, type(uint256).max / 10 ** 36);

        // And: Cast to uint160 in _getSqrtPriceX96 does not overflow.
        if (asset1.usdValue > 0) {
            vm.assume(asset0.usdValue / asset1.usdValue / 10 ** asset0.decimals < 2 ** 128 / 10 ** asset1.decimals);
        }

        // And: position is valid.
        position = givenValidPosition(position);

        // And: there is no fee.
        // ToDo: include fees.
        position.feeGrowthInside0LastX128 = 0;
        position.feeGrowthInside1LastX128 = 0;
        position.tokensOwed0 = 0;
        position.tokensOwed1 = 0;

        // And: State is persisted.
        addUnderlyingTokenToArcadia(address(token0), int256(asset0.usdValue));
        addUnderlyingTokenToArcadia(address(token1), int256(asset1.usdValue));
        IUniswapV3PoolExtension pool = createPool(token0, token1, 1e18, 300);
        nonfungiblePositionManagerMock.setPosition(address(pool), tokenId, position);

        // When: "getUnderlyingAssetsAmounts" is called.
        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock)));
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
                uniV3AssetModule.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
        }

        // Then: The correct "rateUnderlyingAssetsToUsd" are returned.
        uint256 expectedRateUnderlyingAssetsToUsd0 = asset0.usdValue * 10 ** (36 - asset0.decimals);
        uint256 expectedRateUnderlyingAssetsToUsd1 = asset1.usdValue * 10 ** (36 - asset1.decimals);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, expectedRateUnderlyingAssetsToUsd0);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, expectedRateUnderlyingAssetsToUsd1);

        // And: The correct "underlyingAssetsAmounts" rates are returned.
        uint160 sqrtPriceX96 =
            uniV3AssetModule.getSqrtPriceX96(expectedRateUnderlyingAssetsToUsd0, expectedRateUnderlyingAssetsToUsd1);
        (uint256 expectedUnderlyingAssetsAmount0, uint256 expectedUnderlyingAssetsAmount1) = LiquidityAmounts
            .getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            position.liquidity
        );
        assertEq(underlyingAssetsAmounts[0], expectedUnderlyingAssetsAmount0);
        assertEq(underlyingAssetsAmounts[1], expectedUnderlyingAssetsAmount1);
    }

    function testFuzz_Success_GetUnderlyingAssetsAmounts_AmountIsZero(uint96 tokenId) public {
        // Given : Zero amount
        uint256 amount = 0;

        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(nonfungiblePositionManagerMock)));

        // When: "getUnderlyingAssetsAmounts" is called.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            uniV3AssetModule.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, amount, new bytes32[](0));

        // Then: Values returned should be zero.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }
}
