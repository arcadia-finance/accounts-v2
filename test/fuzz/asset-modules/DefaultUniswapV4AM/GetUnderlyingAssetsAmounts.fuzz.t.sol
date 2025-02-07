/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { DefaultUniswapV4AM_Fuzz_Test } from "./_DefaultUniswapV4AM.fuzz.t.sol";
import { FixedPoint128 } from "../../../../lib/v4-periphery/lib/v4-core/src/libraries/FixedPoint128.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { PositionInfo, PositionInfoLibrary } from "../../../../lib/v4-periphery/src/libraries/PositionInfoLibrary.sol";
import { TickMath } from "../../../../lib/v4-periphery/lib/v4-core/src/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "_getUnderlyingAssetsAmounts" of contract "DefaultUniswapV4AM".
 */
contract GetUnderlyingAssetsAmounts_DefaultUniswapV4AM_Fuzz_Test is DefaultUniswapV4AM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DefaultUniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_GetUnderlyingAssetsAmounts_Overflow_PriceToken0(
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1
    ) public {
        // Given: underlying asset decimals are equal or less than 18.
        asset0.decimals = bound(asset0.decimals, 0, 18);
        asset1.decimals = bound(asset1.decimals, 0, 18);

        ERC20Mock token0_ = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1_ = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (token0_ > token1_) {
            (token0_, token1_) = (token1_, token0_);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: "rateUnderlyingAssetsToUsd" for token0_ overflows in "_getRateUnderlyingAssetsToUsd" (test-case).
        // Or: "priceXd18" overflows in "_getSqrtPriceX96" (test-case).
        // And: "usdValue" for token0_ does not overflow on cast to int256.
        if (asset1.usdValue > 0) {
            asset0.usdValue = bound(asset0.usdValue, type(uint256).max / 10 ** (46 - asset0.decimals) + 1, INT256_MAX);
        } else {
            asset0.usdValue = bound(asset0.usdValue, type(uint256).max / 10 ** 18 + 1, INT256_MAX);
        }

        // And: "rateUnderlyingAssetsToUsd" for token1_ does not overflows in "_getRateUnderlyingAssetsToUsd".
        asset1.usdValue = bound(asset1.usdValue, 0, type(uint256).max / 10 ** 18);

        // And: State is valid for pool and position.
        randomPoolKey = initializePool(address(token0_), address(token1_), 1e18, address(validHook), 500, 1);
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(randomPoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, randomPoolKey, tickLower, tickUpper, tokenId);

        // And: Both tokens are added to the Registry.
        addAssetToArcadia(address(token0_), int256(asset0.usdValue));
        addAssetToArcadia(address(token1_), int256(asset1.usdValue));

        // When: "getUnderlyingAssetsAmounts" is called.
        // Then: The transaction overflows.
        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));
        vm.expectRevert(bytes(""));
        uniswapV4AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
    }

    function testFuzz_Revert_GetUnderlyingAssetsAmounts_Overflow_PriceToken1(
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1
    ) public {
        // Given: underlying asset decimals are equal or less than 18.
        asset0.decimals = bound(asset0.decimals, 0, 18);
        asset1.decimals = bound(asset1.decimals, 0, 18);

        ERC20Mock token0_ = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1_ = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (token0_ > token1_) {
            (token0_, token1_) = (token1_, token0_);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: "priceXd18" does not overflow in "_getSqrtPriceX96".
        asset0.usdValue = bound(asset0.usdValue, 0, type(uint256).max / 10 ** (46 - asset0.decimals));

        // And: "rateUnderlyingAssetsToUsd" for token1_ overflows in "_getRateUnderlyingAssetsToUsd" (test-case).
        // And: "usdValue" for token1_ does not overflow on cast to int256.
        asset1.usdValue = bound(asset1.usdValue, type(uint256).max / 10 ** 18 + 1, INT256_MAX);

        // And: State is valid for pool and position.
        randomPoolKey = initializePool(address(token0_), address(token1_), 1e18, address(validHook), 500, 1);
        (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);
        vm.assume(liquidity > 0);
        bytes32 positionKey =
            keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
        poolManager.setPositionLiquidity(randomPoolKey.toId(), positionKey, liquidity);
        positionManager.setPosition(users.owner, randomPoolKey, tickLower, tickUpper, tokenId);

        // And: Both tokens are added to the Registry.
        addAssetToArcadia(address(token0_), int256(asset0.usdValue));
        addAssetToArcadia(address(token1_), int256(asset1.usdValue));

        // When: "getUnderlyingAssetsAmounts" is called.
        // Then: The transaction overflows.
        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));
        vm.expectRevert(bytes(""));
        uniswapV4AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
    }

    function testFuzz_Success_GetUnderlyingAssetsAmounts_AmountIsZero(uint96 tokenId) public {
        // Given : Zero amount
        uint256 amount = 0;

        bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));

        // When: "getUnderlyingAssetsAmounts" is called.
        (uint256[] memory underlyingAssetsAmounts, AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd) =
            uniswapV4AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, amount, new bytes32[](0));

        // Then: Values returned should be zero.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_GetUnderlyingAssetsAmounts(
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1,
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity
    ) public {
        // Given: underlying asset decimals are between 6 and 18 decimals.
        asset0.decimals = bound(asset0.decimals, 6, 18);
        asset1.decimals = bound(asset1.decimals, 6, 18);

        ERC20Mock token0_ = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        ERC20Mock token1_ = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (token0_ > token1_) {
            (token0_, token1_) = (token1_, token0_);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: "priceXd18" does not overflow in "_getSqrtPriceX96".
        asset0.usdValue = bound(asset0.usdValue, 0, type(uint256).max / 10 ** (46 - asset0.decimals));

        // And: No overflow in capped fee calculation (max fee that can be considered as underlying amount to avoid bypassing max exposure)
        asset1.usdValue = bound(asset1.usdValue, 0, type(uint256).max / 10 ** (46 - asset1.decimals));

        // And: Cast to uint160 in _getSqrtPriceX96 does not overflow.
        if (asset1.usdValue > 0) {
            vm.assume(asset0.usdValue / asset1.usdValue / 10 ** asset0.decimals < 2 ** 128 / 10 ** asset1.decimals);
        }

        // Calculate and check that tick current is within allowed ranges.
        uint160 sqrtPriceX96_ = uint160(calculateAndValidateRangeTickCurrent(asset0.usdValue, asset1.usdValue));
        vm.assume(isWithinAllowedRangeV4(TickMath.getTickAtSqrtPrice(sqrtPriceX96_)));

        // And: State is valid for pool and position.
        {
            randomPoolKey =
                initializePool(address(token0_), address(token1_), sqrtPriceX96_, address(validHook), 500, 1);
            (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);
            bytes32 positionKey =
                keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));

            vm.assume(liquidity > 0);
            // And: No overflow in capped fee calculation (max fee that can be considered as underlying amount to avoid bypassing max exposure)
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96_, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity
            );
            vm.assume(amount0 < type(uint96).max);
            vm.assume(amount1 < type(uint96).max);

            // And: principals do not overflow.
            vm.assume(amount0 < type(uint256).max / (asset0.usdValue * 10 ** (18 - asset0.decimals)));
            vm.assume(amount1 < type(uint256).max / (asset1.usdValue * 10 ** (18 - asset1.decimals)));

            poolManager.setPositionLiquidity(randomPoolKey.toId(), positionKey, liquidity);
            positionManager.setPosition(users.owner, randomPoolKey, tickLower, tickUpper, tokenId);
        }

        // And: Both tokens are added to the Registry.
        addAssetToArcadia(address(token0_), int256(asset0.usdValue));
        addAssetToArcadia(address(token1_), int256(asset1.usdValue));

        // When: "getUnderlyingAssetsAmounts" is called.
        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
                uniswapV4AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
        }

        // Then: The correct "rateUnderlyingAssetsToUsd" are returned.
        uint256 expectedRateUnderlyingAssetsToUsd0 = asset0.usdValue * 10 ** (18 - asset0.decimals);
        uint256 expectedRateUnderlyingAssetsToUsd1 = asset1.usdValue * 10 ** (18 - asset1.decimals);
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, expectedRateUnderlyingAssetsToUsd0);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, expectedRateUnderlyingAssetsToUsd1);

        // And: The correct "underlyingAssetsAmounts" rates are returned.
        uint160 sqrtPriceX96 =
            uniswapV4AM.getSqrtPriceX96(expectedRateUnderlyingAssetsToUsd0, expectedRateUnderlyingAssetsToUsd1);
        (uint256 expectedUnderlyingAssetsAmount0, uint256 expectedUnderlyingAssetsAmount1) = LiquidityAmounts
            .getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity
        );
        assertEq(underlyingAssetsAmounts[0], expectedUnderlyingAssetsAmount0);
        assertEq(underlyingAssetsAmounts[1], expectedUnderlyingAssetsAmount1);
    }

    function testFuzz_Success_GetUnderlyingAssetsAmounts_getFeeAmounts_NotCapped(
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1,
        uint96 tokenId,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        FeeGrowth memory feeData
    ) public {
        // Given: underlying asset decimals are between 6 and 18 decimals.
        asset0.decimals = bound(asset0.decimals, 6, 18);
        asset1.decimals = bound(asset1.decimals, 6, 18);

        token0 = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        token1 = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: Reasonable prices.
        asset0.usdValue = bound(asset0.usdValue, 0, type(uint128).max / 10 ** (46 - asset0.decimals));

        // And: No overflow in capped fee calculation (max fee that can be considered as underlying amount to avoid bypassing max exposure)
        asset1.usdValue = bound(asset1.usdValue, 0, type(uint128).max / 10 ** (46 - asset1.decimals));

        // And: Cast to uint160 in _getSqrtPriceX96 does not overflow.
        if (asset1.usdValue > 0) {
            vm.assume(asset0.usdValue / asset1.usdValue / 10 ** asset0.decimals < 2 ** 128 / 10 ** asset1.decimals);
        }

        // Calculate and check that tick current is within allowed ranges.
        {
            uint160 sqrtPriceX96_ = uint160(calculateAndValidateRangeTickCurrent(asset0.usdValue, asset1.usdValue));
            vm.assume(isWithinAllowedRangeV4(TickMath.getTickAtSqrtPrice(sqrtPriceX96_)));

            // And: State is valid for pool and position.
            randomPoolKey = initializePool(address(token0), address(token1), sqrtPriceX96_, address(validHook), 500, 1);
            (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);
            bytes32 positionKey =
                keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));

            vm.assume(liquidity > 0);
            // And: No overflow in capped fee calculation (max fee that can be considered as underlying amount to avoid bypassing max exposure)
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96_, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity
            );
            vm.assume(amount0 < type(uint96).max);
            vm.assume(amount1 < type(uint96).max);

            poolManager.setPositionLiquidity(randomPoolKey.toId(), positionKey, liquidity);
            positionManager.setPosition(users.owner, randomPoolKey, tickLower, tickUpper, tokenId);
        }

        // And: Both tokens are added to the Registry.
        addAssetToArcadia(address(token0), int256(asset0.usdValue));
        addAssetToArcadia(address(token1), int256(asset1.usdValue));

        uint256 principleInAmount0;
        uint256 principleInAmount1;
        uint256[] memory underlyingAssetsAmounts;
        {
            {
                AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
                {
                    bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));
                    (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
                        uniswapV4AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
                }

                principleInAmount0 = underlyingAssetsAmounts[0]
                    + underlyingAssetsAmounts[1] * rateUnderlyingAssetsToUsd[1].assetValue
                        / rateUnderlyingAssetsToUsd[0].assetValue;
                principleInAmount1 = underlyingAssetsAmounts[1]
                    + underlyingAssetsAmounts[0] * rateUnderlyingAssetsToUsd[0].assetValue
                        / rateUnderlyingAssetsToUsd[1].assetValue;
            }

            // And : Fee is not capped.
            feeData.desiredFee0 = bound(feeData.desiredFee0, 0, principleInAmount0);
            feeData.desiredFee1 = bound(feeData.desiredFee1, 0, principleInAmount1);

            // And : Calculate expected feeGrowth difference in order to obtain desired fee
            // (fee * Q128) / liquidity = diff in Q128.
            {
                uint256 feeGrowthDiff0X128 = feeData.desiredFee0.mulDivDown(FixedPoint128.Q128, liquidity);
                feeData.upperFeeGrowthOutside0X128 =
                    bound(feeData.upperFeeGrowthOutside0X128, 0, type(uint256).max - feeGrowthDiff0X128);
                feeData.lowerFeeGrowthOutside0X128 = feeData.upperFeeGrowthOutside0X128 + feeGrowthDiff0X128;
            }

            {
                uint256 feeGrowthDiff1X128 = feeData.desiredFee1.mulDivDown(FixedPoint128.Q128, liquidity);
                feeData.upperFeeGrowthOutside1X128 =
                    bound(feeData.upperFeeGrowthOutside1X128, 0, type(uint256).max - feeGrowthDiff1X128);
                feeData.lowerFeeGrowthOutside1X128 = feeData.upperFeeGrowthOutside1X128 + feeGrowthDiff1X128;
            }

            poolManager.setFeeGrowthOutside(
                randomPoolKey.toId(),
                tickLower,
                tickUpper,
                feeData.lowerFeeGrowthOutside0X128,
                feeData.upperFeeGrowthOutside0X128,
                feeData.lowerFeeGrowthOutside1X128,
                feeData.upperFeeGrowthOutside1X128
            );
        }

        (uint256 fee0, uint256 fee1) = uniswapV4AM.getFeeAmounts(
            tokenId,
            randomPoolKey.toId(),
            PositionInfoLibrary.initialize(randomPoolKey, tickLower, tickUpper),
            liquidity
        );
        vm.assume(fee0 < principleInAmount0);
        vm.assume(fee1 < principleInAmount1);

        // When: "getUnderlyingAssetsAmounts" is called.
        uint256[] memory underlyingAssetsAmounts_;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));
            (underlyingAssetsAmounts_,) =
                uniswapV4AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
        }

        // And: The correct "underlyingAssetsAmounts" rates are returned.
        assertEq(underlyingAssetsAmounts_[0], underlyingAssetsAmounts[0] + fee0);
        assertEq(underlyingAssetsAmounts_[1], underlyingAssetsAmounts[1] + fee1);
    }

    function testFuzz_Success_GetUnderlyingAssetsAmounts_getFeeAmounts_Capped(
        UnderlyingAssetState memory asset0,
        UnderlyingAssetState memory asset1,
        uint96 tokenId,
        uint128 liquidity,
        int24 tickLower,
        int24 tickUpper,
        FeeGrowth memory feeData
    ) public {
        // Given: underlying asset decimals are between 6 and 18 decimals.
        asset0.decimals = bound(asset0.decimals, 6, 18);
        asset1.decimals = bound(asset1.decimals, 6, 18);

        token0 = new ERC20Mock("Token 0", "TOK0", uint8(asset0.decimals));
        token1 = new ERC20Mock("Token 1", "TOK1", uint8(asset1.decimals));
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
            (asset0, asset1) = (asset1, asset0);
        }

        // And: Reasonable prices.
        asset0.usdValue = bound(asset0.usdValue, 0, type(uint128).max / 10 ** (46 - asset0.decimals));

        // And: No overflow in capped fee calculation (max fee that can be considered as underlying amount to avoid bypassing max exposure)
        asset1.usdValue = bound(asset1.usdValue, 0, type(uint128).max / 10 ** (46 - asset1.decimals));

        // And: Cast to uint160 in _getSqrtPriceX96 does not overflow.
        if (asset1.usdValue > 0) {
            vm.assume(asset0.usdValue / asset1.usdValue / 10 ** asset0.decimals < 2 ** 128 / 10 ** asset1.decimals);
        }

        // Calculate and check that tick current is within allowed ranges.
        {
            uint160 sqrtPriceX96_ = uint160(calculateAndValidateRangeTickCurrent(asset0.usdValue, asset1.usdValue));
            vm.assume(isWithinAllowedRangeV4(TickMath.getTickAtSqrtPrice(sqrtPriceX96_)));

            // And: State is valid for pool and position.
            randomPoolKey = initializePool(address(token0), address(token1), sqrtPriceX96_, address(validHook), 500, 1);
            (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);
            bytes32 positionKey =
                keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));

            vm.assume(liquidity > 0);
            // And: No overflow in capped fee calculation (max fee that can be considered as underlying amount to avoid bypassing max exposure)
            (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
                sqrtPriceX96_, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity
            );
            vm.assume(amount0 < type(uint96).max);
            vm.assume(amount1 < type(uint96).max);

            poolManager.setPositionLiquidity(randomPoolKey.toId(), positionKey, liquidity);
            positionManager.setPosition(users.owner, randomPoolKey, tickLower, tickUpper, tokenId);
        }

        // And: Both tokens are added to the Registry.
        addAssetToArcadia(address(token0), int256(asset0.usdValue));
        addAssetToArcadia(address(token1), int256(asset1.usdValue));

        uint256 principleInAmount0;
        uint256 principleInAmount1;
        uint256[] memory underlyingAssetsAmounts;
        {
            {
                AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
                {
                    bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));
                    (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) =
                        uniswapV4AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
                }

                principleInAmount0 = underlyingAssetsAmounts[0]
                    + underlyingAssetsAmounts[1] * rateUnderlyingAssetsToUsd[1].assetValue
                        / rateUnderlyingAssetsToUsd[0].assetValue;
                principleInAmount1 = underlyingAssetsAmounts[1]
                    + underlyingAssetsAmounts[0] * rateUnderlyingAssetsToUsd[0].assetValue
                        / rateUnderlyingAssetsToUsd[1].assetValue;
            }

            // And : Fee is not capped.
            vm.assume(principleInAmount0 < type(uint112).max);
            vm.assume(principleInAmount1 < type(uint112).max);
            feeData.desiredFee0 = bound(feeData.desiredFee0, principleInAmount0, type(uint112).max);
            feeData.desiredFee1 = bound(feeData.desiredFee1, principleInAmount1, type(uint112).max);

            // And : Calculate expected feeGrowth difference in order to obtain desired fee
            // (fee * Q128) / liquidity = diff in Q128.
            {
                uint256 feeGrowthDiff0X128 = feeData.desiredFee0.mulDivDown(FixedPoint128.Q128, liquidity);
                feeData.upperFeeGrowthOutside0X128 =
                    bound(feeData.upperFeeGrowthOutside0X128, 0, type(uint256).max - feeGrowthDiff0X128);
                feeData.lowerFeeGrowthOutside0X128 = feeData.upperFeeGrowthOutside0X128 + feeGrowthDiff0X128;
            }

            {
                uint256 feeGrowthDiff1X128 = feeData.desiredFee1.mulDivDown(FixedPoint128.Q128, liquidity);
                feeData.upperFeeGrowthOutside1X128 =
                    bound(feeData.upperFeeGrowthOutside1X128, 0, type(uint256).max - feeGrowthDiff1X128);
                feeData.lowerFeeGrowthOutside1X128 = feeData.upperFeeGrowthOutside1X128 + feeGrowthDiff1X128;
            }

            poolManager.setFeeGrowthOutside(
                randomPoolKey.toId(),
                tickLower,
                tickUpper,
                feeData.lowerFeeGrowthOutside0X128,
                feeData.upperFeeGrowthOutside0X128,
                feeData.lowerFeeGrowthOutside1X128,
                feeData.upperFeeGrowthOutside1X128
            );
        }

        (uint256 fee0, uint256 fee1) = uniswapV4AM.getFeeAmounts(
            tokenId,
            randomPoolKey.toId(),
            PositionInfoLibrary.initialize(randomPoolKey, tickLower, tickUpper),
            liquidity
        );
        vm.assume(fee0 >= principleInAmount0);
        vm.assume(fee1 >= principleInAmount1);

        // When: "getUnderlyingAssetsAmounts" is called.
        uint256[] memory underlyingAssetsAmounts_;
        {
            bytes32 assetKey = bytes32(abi.encodePacked(tokenId, address(positionManager)));
            (underlyingAssetsAmounts_,) =
                uniswapV4AM.getUnderlyingAssetsAmounts(address(creditorUsd), assetKey, 1, new bytes32[](0));
        }

        // And: The correct "underlyingAssetsAmounts" rates are returned.
        assertEq(underlyingAssetsAmounts_[0], underlyingAssetsAmounts[0] + principleInAmount0);
        assertEq(underlyingAssetsAmounts_[1], underlyingAssetsAmounts[1] + principleInAmount1);
    }
}
