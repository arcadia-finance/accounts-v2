/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../../src/libraries/AssetValuationLib.sol";
import { ICLSwapRouter } from "../../../utils/fixtures/slipstream/interfaces/ICLSwapRouter.sol";
import { IMockSwapHook } from "../../../utils/mocks/Metadex03/interfaces/IMockSwapHook.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV3/libraries/LiquidityAmounts.sol";
import { StakedMetadex03CLAM_Fuzz_Test } from "./_StakedMetadex03CLAM.fuzz.t.sol";
import { StakedSlipstreamAM } from "../../../../src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StdStorage, stdStorage } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

/**
 * @notice Fuzz tests for the function "getUnderlyingAssetsAmounts" of contract "StakedMetadex03CLAM".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract GetUnderlyingAssetsAmounts_StakedMetadex03CLAM_Fuzz_Test is StakedMetadex03CLAM_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    IMockSwapHook internal swapHook;

    function setUp() public override {
        StakedMetadex03CLAM_Fuzz_Test.setUp();

        deployStakedMetadex03CLAM();
        deployMetadex03SwapRouter(address(metadex03CLFactory), address(weth9));
        swapHook = IMockSwapHook(deployCode("MockSwapHook.sol"));
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
        // Given: A valid position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));

        // And: The USD price of token1 is not zero and does not overflow the Oracle Module.
        priceToken1 = bound(priceToken1, 1, type(uint256).max / 1e18);

        // And: The intermediate product of the price of token0 does not overflow.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);

        // And: The relative price stays below the 2 ** 128 at which the sqrt price overflows uint160.
        if (priceToken1 <= type(uint256).max / 1e28 / 2 ** 128) {
            priceToken0 = bound(priceToken0, 0, priceToken1 * 2 ** 128 - 1);
        }

        // And: A gauge on a pool of two allowed tokens at those prices.
        deployAndAddGaugeAtPrices(tick, priceToken0, priceToken1);

        // And: An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // And: The position is staked.
            uint256 assetId = _stakePosition(position);

            // And: The reward growth of the pool moved.
            vm.warp(block.timestamp + 1);
            stdstore.target(address(pool))
                .sig(pool.rewardGrowthGlobalX128.selector)
                .checked_write(rewardGrowthGlobalX128Current);

            // When: The underlying assets amounts are read for an exposure of zero.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedMetadex03CLAM)));
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = stakedMetadex03CLAM.getUnderlyingAssetsAmounts(
                address(0), assetKey, 0, stakedMetadex03CLAM.getUnderlyingAssets(assetKey)
            );
        }

        // Then: Nothing is valued.
        assertEq(underlyingAssetsAmounts[0], 0);
        assertEq(underlyingAssetsAmounts[1], 0);
        assertEq(underlyingAssetsAmounts[2], 0);

        // And: No rates are returned.
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
        // Given: A valid position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));

        // And: The USD price of token1 is not zero and does not overflow the Oracle Module.
        priceToken1 = bound(priceToken1, 1, type(uint256).max / 1e18);

        // And: The intermediate product of the price of token0 does not overflow.
        priceToken0 = bound(priceToken0, 0, type(uint256).max / 1e28);

        // And: The relative price stays below the 2 ** 128 at which the sqrt price overflows uint160.
        if (priceToken1 <= type(uint256).max / 1e28 / 2 ** 128) {
            priceToken0 = bound(priceToken0, 0, priceToken1 * 2 ** 128 - 1);
        }

        // And: A gauge on a pool of two allowed tokens at those prices.
        deployAndAddGaugeAtPrices(tick, priceToken0, priceToken1);

        // And: An initial rewardGrowthGlobalX128.
        stdstore.target(address(pool))
            .sig(pool.rewardGrowthGlobalX128.selector)
            .checked_write(rewardGrowthGlobalX128Last);

        uint256[] memory underlyingAssetsAmounts;
        AssetValueAndRiskFactors[] memory rateUnderlyingAssetsToUsd;
        {
            // And: The position is staked.
            uint256 assetId = _stakePosition(position);

            // And: The reward growth of the pool moved.
            vm.warp(block.timestamp + 1);
            stdstore.target(address(pool))
                .sig(pool.rewardGrowthGlobalX128.selector)
                .checked_write(rewardGrowthGlobalX128Current);

            // When: The underlying assets amounts are read for an exposure of one.
            bytes32 assetKey = bytes32(abi.encodePacked(uint96(assetId), address(stakedMetadex03CLAM)));
            (underlyingAssetsAmounts, rateUnderlyingAssetsToUsd) = stakedMetadex03CLAM.getUnderlyingAssetsAmounts(
                address(0), assetKey, 1, stakedMetadex03CLAM.getUnderlyingAssets(assetKey)
            );
        }

        // Then: The token amounts of the liquidity position at the trusted price are returned.
        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            stakedMetadex03CLAM.getSqrtPriceX96(priceToken0, priceToken1),
            TickMath.getSqrtRatioAtTick(position.tickLower),
            TickMath.getSqrtRatioAtTick(position.tickUpper),
            uint128(getActualLiquidity(position))
        );
        assertEq(underlyingAssetsAmounts[0], amount0Expected);
        assertEq(underlyingAssetsAmounts[1], amount1Expected);

        // And: The reward is not valued, the gauge can defer it on a withdrawal.
        assertEq(underlyingAssetsAmounts[2], 0);

        // And: The trusted rates of all three underlying assets are returned.
        assertEq(rateUnderlyingAssetsToUsd[0].assetValue, priceToken0);
        assertEq(rateUnderlyingAssetsToUsd[1].assetValue, priceToken1);
        assertEq(rateUnderlyingAssetsToUsd[2].assetValue, rates.token1ToUsd);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_Metadex03Reverts(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick
    ) public {
        // Given: A staked position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        uint256 assetId = initStakedPosition(position, tick);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: Every Metadex03 contract reverts on every call.
        vm.mockCallRevert(address(gauge), bytes(""), bytes(""));
        vm.mockCallRevert(address(metadex03CLGaugeFactory), bytes(""), bytes(""));
        vm.mockCallRevert(address(leafVoter), bytes(""), bytes(""));
        vm.mockCallRevert(emissionsHandler, bytes(""), bytes(""));
        vm.mockCallRevert(address(factoryRegistryMetadex03), bytes(""), bytes(""));
        vm.mockCallRevert(rewardToken, bytes(""), bytes(""));
        vm.mockCallRevert(address(pool), bytes(""), bytes(""));
        vm.mockCallRevert(address(metadex03CLFactory), bytes(""), bytes(""));
        vm.mockCallRevert(address(metadex03PositionManager), bytes(""), bytes(""));

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation is unaffected, so the position stays liquidatable.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_MaxCeilingHook(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick
    ) public {
        // Given: A staked position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        uint256 assetId = initStakedPosition(position, tick);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: A hook returning the maximum fee is set on the pool.
        swapHook.setFee(SWAP_FEE_CEIL);
        setSwapHookMetadex03CL(address(pool), address(swapHook));

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation is unaffected.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.burn(assetId);

        // Then: The position is transferred back to the owner.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_RevertingHook(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick
    ) public {
        // Given: A staked position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        uint256 assetId = initStakedPosition(position, tick);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: A reverting hook is set on the pool.
        swapHook.setShouldRevert(true);
        setSwapHookMetadex03CL(address(pool), address(swapHook));

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation is unaffected.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.burn(assetId);

        // Then: The position is transferred back to the owner.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_MalformedHook(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick
    ) public {
        // Given: A staked position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        uint256 assetId = initStakedPosition(position, tick);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: A hook returning malformed data is set on the pool.
        swapHook.setReturnMalformed(true);
        setSwapHookMetadex03CL(address(pool), address(swapHook));

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation is unaffected.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.burn(assetId);

        // Then: The position is transferred back to the owner.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_OverCeilingHook(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick,
        uint24 feeOverCeiling
    ) public {
        // Given: A staked position with the current tick of the pool in its range.
        position = givenValidPosition(position, 1);
        tick = int24(bound(tick, position.tickLower, position.tickUpper - 1));
        uint256 assetId = initStakedPosition(position, tick);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: A hook returning a fee above the ceiling is set on the pool.
        // forge-lint: disable-next-item(unsafe-typecast)
        feeOverCeiling = uint24(bound(feeOverCeiling, SWAP_FEE_CEIL + 1, type(uint24).max));
        swapHook.setFee(feeOverCeiling);
        setSwapHookMetadex03CL(address(pool), address(swapHook));

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation is unaffected.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);

        // When: The liquidity provider burns the position.
        vm.prank(users.liquidityProvider);
        stakedMetadex03CLAM.burn(assetId);

        // Then: The position is transferred back to the owner.
        assertEq(metadex03PositionManager.ownerOf(assetId), users.liquidityProvider);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_AfterSwap_MaxCeilingHook(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick,
        uint256 amountIn
    ) public {
        // Given: A staked position the pool can be swapped through.
        uint256 assetId;
        (position, assetId, amountIn) = stageSwappablePosition(position, tick, amountIn);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: A hook returning the maximum fee is set on the pool.
        swapHook.setFee(SWAP_FEE_CEIL);
        setSwapHookMetadex03CL(address(pool), address(swapHook));

        // When: The pool is swapped through.
        uint256 amountOut = swapThroughPool(position, amountIn);

        // Then: The swap completed with the hook fee applied.
        assertGt(amountOut, 0);

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation of the staked position is unaffected by the hook fee.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_RevertingHook_SwapReverts(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick,
        uint256 amountIn
    ) public {
        // Given: A staked position the pool can be swapped through.
        uint256 assetId;
        (position, assetId, amountIn) = stageSwappablePosition(position, tick, amountIn);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: A reverting hook is set on the pool.
        swapHook.setShouldRevert(true);
        setSwapHookMetadex03CL(address(pool), address(swapHook));

        // And: The swapper holds the input and approved the router.
        deal(address(token0), users.swapper, amountIn, true);
        vm.prank(users.swapper);
        token0.approve(address(metadex03CLSwapRouter), amountIn);
        ICLSwapRouter.ExactInputSingleParams memory params = ICLSwapRouter.ExactInputSingleParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            tickSpacing: 1,
            recipient: users.swapper,
            deadline: type(uint256).max,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: TickMath.getSqrtRatioAtTick(position.tickLower)
        });

        // When: The swapper swaps through the pool.
        // Then: It reverts with the reason of the hook.
        vm.prank(users.swapper);
        vm.expectRevert(bytes("HOOK"));
        metadex03CLSwapRouter.exactInputSingle(params);

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation of the staked position still resolves, unchanged.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_MalformedHook_SwapReverts(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick,
        uint256 amountIn
    ) public {
        // Given: A staked position the pool can be swapped through.
        uint256 assetId;
        (position, assetId, amountIn) = stageSwappablePosition(position, tick, amountIn);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: A hook returning malformed data is set on the pool.
        swapHook.setReturnMalformed(true);
        setSwapHookMetadex03CL(address(pool), address(swapHook));

        // And: The swapper holds the input and approved the router.
        deal(address(token0), users.swapper, amountIn, true);
        vm.prank(users.swapper);
        token0.approve(address(metadex03CLSwapRouter), amountIn);
        ICLSwapRouter.ExactInputSingleParams memory params = ICLSwapRouter.ExactInputSingleParams({
            tokenIn: address(token0),
            tokenOut: address(token1),
            tickSpacing: 1,
            recipient: users.swapper,
            deadline: type(uint256).max,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: TickMath.getSqrtRatioAtTick(position.tickLower)
        });

        // When: The swapper swaps through the pool.
        // Then: It reverts on the undecodable return data.
        vm.prank(users.swapper);
        vm.expectRevert(bytes(""));
        metadex03CLSwapRouter.exactInputSingle(params);

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation of the staked position still resolves, unchanged.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);
    }

    function testFuzz_Success_getUnderlyingAssetsAmounts_AfterSwap_OverCeilingHook(
        StakedSlipstreamAM.PositionState memory position,
        int24 tick,
        uint256 amountIn,
        uint24 feeOverCeiling
    ) public {
        // Given: A staked position the pool can be swapped through.
        uint256 assetId;
        (position, assetId, amountIn) = stageSwappablePosition(position, tick, amountIn);
        (uint256[] memory amountsBefore,) = getValuation(assetId);

        // And: A hook returning a fee above the ceiling is set on the pool.
        feeOverCeiling = uint24(bound(feeOverCeiling, SWAP_FEE_CEIL + 1, type(uint24).max));
        swapHook.setFee(feeOverCeiling);
        setSwapHookMetadex03CL(address(pool), address(swapHook));

        // When: The pool is swapped through.
        uint256 amountOut = swapThroughPool(position, amountIn);

        // Then: The swap completed via the fallback fee.
        assertGt(amountOut, 0);

        // When: The underlying assets amounts are read.
        (uint256[] memory amountsAfter,) = getValuation(assetId);

        // Then: The valuation of the staked position is unaffected by the hook fee.
        assertEq(amountsAfter[0], amountsBefore[0]);
        assertEq(amountsAfter[1], amountsBefore[1]);
        assertEq(amountsAfter[2], amountsBefore[2]);
    }
}
