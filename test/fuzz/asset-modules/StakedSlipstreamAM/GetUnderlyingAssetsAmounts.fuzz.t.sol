/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { StakedSlipstreamAM_Fuzz_Test } from "./_StakedSlipstreamAM.fuzz.t.sol";

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { ERC20Mock } from "../../../utils/mocks/tokens/ERC20Mock.sol";
import { FixedPoint128 } from "../../../../src/asset-modules/UniswapV3/libraries/FixedPoint128.sol";
import { FullMath } from "../../../../src/asset-modules/UniswapV3/libraries/FullMath.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssetsAmounts" of contract "StakedSlipstreamAM".
 */
contract GetUnderlyingAssetsAmounts_StakedSlipstreamAM_Fuzz_Test is StakedSlipstreamAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        StakedSlipstreamAM_Fuzz_Test.setUp();

        deployStakedSlipstreamAM();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_getUnderlyingAssetsAmounts_WithoutExposure(
        int24 tick,
        StakedSlipstreamAM.PositionState memory position,
        uint256 priceToken0,
        uint256 priceToken1,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current
    ) public {
        // Given: Ticks are within allowed ranges.
        position = givenValidPosition(position, 1);

        // And : the current tick of the pool is in range (can't be equal to tickUpper, but can be equal to tickLower).
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));

        // And : Prices are valid.
        // Avoid divide by 0, which is already checked in earlier in function.
        // priceToken1 can't overflow in Oracle Module.
        priceToken1 = bound(priceToken1, 1, type(uint256).max / 1e18);
        // Function will overFlow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);
        // Cast to uint160 will overflow, not realistic.
        if (priceToken1 < 2 ** 128) priceToken0 = bound(priceToken0, 0, priceToken1 * 2 ** 128);

        // And : gauge is deployed and added to registry.
        {
            ERC20Mock tokenA = new ERC20Mock("Token A", "TOKENA", 18);
            ERC20Mock tokenB = new ERC20Mock("Token B", "TOKENB", 18);
            uint256 priceTokenA;
            uint256 priceTokenB;
            if (tokenA < tokenB) {
                (token0, token1) = (tokenA, tokenB);
                (priceTokenA, priceTokenB) = (priceToken0, priceToken1);
            } else {
                (token0, token1) = (tokenB, tokenA);
                (priceTokenA, priceTokenB) = (priceToken1, priceToken0);
            }
            deployPoolAndGauge(token0, token1, TickMath.getSqrtRatioAtTick(tick), 300);
            addUnderlyingTokenToArcadia(address(tokenA), int256(priceTokenA));
            addUnderlyingTokenToArcadia(address(tokenB), int256(priceTokenB));
            vm.prank(users.owner);
            stakedSlipstreamAM.addGauge(address(gauge));
        }

        // And : An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector).checked_write(
            rewardGrowthGlobalX128Last
        );

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // And : assetId is minted.
            uint256 assetId = addLiquidity(position);

            // And: Position is staked.
            vm.startPrank(users.liquidityProvider);
            slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
            stakedSlipstreamAM.mint(assetId);
            vm.stopPrank();

            // And : Rewards are earned.
            vm.warp(block.timestamp + 1);
            deal(AERO, address(gauge), type(uint256).max, true);
            stdstore.target(address(pool)).sig(pool.rewardReserve.selector).checked_write(type(uint256).max);
            stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector).checked_write(
                rewardGrowthGlobalX128Current
            );

            // When : getUnderlyingAssetsAmounts is called with amount 0.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedSlipstreamAM)));
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = stakedSlipstreamAM.getUnderlyingAssetsAmounts(
                address(0), assetKey, 0, stakedSlipstreamAM.getUnderlyingAssets(assetKey)
            );
        }

        // Then : Correct principle amounts are returned.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(underlyingAssetsAmounts[2], 0);

        // And : correct rates are returned.
        assertEq(rateUnderlyingAssetsToUsd.length, 0);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_WithExposure(
        int24 tick,
        StakedSlipstreamAM.PositionState memory position,
        uint256 priceToken0,
        uint256 priceToken1,
        uint256 rewardGrowthGlobalX128Last,
        uint256 rewardGrowthGlobalX128Current
    ) public {
        // Given: Ticks are within allowed ranges.
        position = givenValidPosition(position, 1);

        // And : the current tick of the pool is in range (can't be equal to tickUpper, but can be equal to tickLower).
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));

        // And : Prices are valid.
        // Avoid divide by 0, which is already checked in earlier in function.
        // priceToken1 can't overflow in Oracle Module.
        priceToken1 = bound(priceToken1, 1, type(uint256).max / 1e18);
        // Function will overFlow, not realistic.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);
        // Cast to uint160 will overflow, not realistic.
        if (priceToken1 < 2 ** 128) priceToken0 = bound(priceToken0, 0, priceToken1 * 2 ** 128);

        // And : gauge is deployed and added to registry.
        {
            ERC20Mock tokenA = new ERC20Mock("Token A", "TOKENA", 18);
            ERC20Mock tokenB = new ERC20Mock("Token B", "TOKENB", 18);
            uint256 priceTokenA;
            uint256 priceTokenB;
            if (tokenA < tokenB) {
                (token0, token1) = (tokenA, tokenB);
                (priceTokenA, priceTokenB) = (priceToken0, priceToken1);
            } else {
                (token0, token1) = (tokenB, tokenA);
                (priceTokenA, priceTokenB) = (priceToken1, priceToken0);
            }
            deployPoolAndGauge(token0, token1, TickMath.getSqrtRatioAtTick(tick), 300);
            addUnderlyingTokenToArcadia(address(tokenA), int256(priceTokenA));
            addUnderlyingTokenToArcadia(address(tokenB), int256(priceTokenB));
            vm.prank(users.owner);
            stakedSlipstreamAM.addGauge(address(gauge));
        }

        // And : An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector).checked_write(
            rewardGrowthGlobalX128Last
        );

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // And : assetId is minted.
            uint256 assetId = addLiquidity(position);

            // And: Position is staked.
            vm.startPrank(users.liquidityProvider);
            slipstreamPositionManager.approve(address(stakedSlipstreamAM), assetId);
            stakedSlipstreamAM.mint(assetId);
            vm.stopPrank();

            // And : Rewards are earned.
            vm.warp(block.timestamp + 1);
            deal(AERO, address(gauge), type(uint256).max, true);
            stdstore.target(address(pool)).sig(pool.rewardReserve.selector).checked_write(type(uint256).max);
            stdstore.target(address(pool)).sig(pool.rewardGrowthGlobalX128.selector).checked_write(
                rewardGrowthGlobalX128Current
            );

            // When : getUnderlyingAssetsAmounts is called with amount 1.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedSlipstreamAM)));
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = stakedSlipstreamAM.getUnderlyingAssetsAmounts(
                address(0), assetKey, 1, stakedSlipstreamAM.getUnderlyingAssets(assetKey)
            );
        }

        // Then : Correct principle amounts are returned.
        uint128 liquidity = uint128(getActualLiquidity(position));
        uint160 sqrtPriceX96 = stakedSlipstreamAM.getSqrtPriceX96(priceToken0, priceToken1);
        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            liquidity
        );
        assertEq(underlyingAssetsAmounts[0], amount0Expected);
        assertEq(underlyingAssetsAmounts[1], amount1Expected);

        // And : Correct reward amounts are returned.
        uint256 rewardGrowthInsideX128;
        unchecked {
            rewardGrowthInsideX128 = rewardGrowthGlobalX128Current - rewardGrowthGlobalX128Last;
        }
        uint256 rewardsExpected = FullMath.mulDiv(rewardGrowthInsideX128, liquidity, FixedPoint128.Q128);
        assertEq(underlyingAssetsAmounts[2], rewardsExpected);

        // And : correct rates are returned.
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, priceToken0);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, priceToken1);
        assertEq(rateUnderlyingAssetsToUsd[2].assetValue, rates.token1ToUsd);
    }
}
