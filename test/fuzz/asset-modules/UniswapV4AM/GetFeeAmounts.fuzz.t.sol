/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { FixedPoint128 } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/FixedPoint128.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import {
    PositionInfo, PositionInfoLibrary
} from "../../../../lib/v4-periphery-fork/src/libraries/PositionInfoLibrary.sol";
import { UniswapV4AM_Fuzz_Test } from "./_UniswapV4AM.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "_getFeeAmounts" of contract "UniswapV4AM".
 */
contract GetFeeAmounts_UniswapV4AM_Fuzz_Test is UniswapV4AM_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        UniswapV4AM_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_success_getFeeAmounts_outOfRangeRight(
        FeeGrowth memory feeData,
        uint128 liquidity,
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper
    ) public {
        // Given : Liquidity is > 0
        vm.assume(liquidity > 0);

        // And : Positive fee
        feeData.desiredFee0 = bound(feeData.desiredFee0, 1, type(uint128).max);
        feeData.desiredFee1 = bound(feeData.desiredFee1, 1, type(uint128).max);

        // And : Calculate expected feeGrowth difference in order to obtain desired fee
        // (fee * Q128) / liquidity = diff in Q128.
        uint256 feeGrowthDiff0X128 = feeData.desiredFee0.mulDivDown(FixedPoint128.Q128, liquidity);

        feeData.upperFeeGrowthOutside0X128 =
            bound(feeData.upperFeeGrowthOutside0X128, 0, type(uint256).max - feeGrowthDiff0X128);
        feeData.lowerFeeGrowthOutside0X128 = feeData.upperFeeGrowthOutside0X128 + feeGrowthDiff0X128;

        uint256 feeGrowthDiff1X128 = feeData.desiredFee1.mulDivDown(FixedPoint128.Q128, liquidity);

        feeData.upperFeeGrowthOutside1X128 =
            bound(feeData.upperFeeGrowthOutside1X128, 0, type(uint256).max - feeGrowthDiff1X128);
        feeData.lowerFeeGrowthOutside1X128 = feeData.upperFeeGrowthOutside1X128 + feeGrowthDiff1X128;

        {
            // And : Current tick should be < lower tick
            (, int24 currentTick,,) = stateView.getSlot0(stablePoolKey.toId());
            tickLower = int24(bound(tickLower, currentTick + 1, MAX_TICK - 1));
            tickUpper = int24(bound(tickUpper, tickLower + 1, MAX_TICK));

            // And : Position is set
            bytes32 positionKey =
                keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
            poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
            positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);
        }

        // And : Valid pool state
        poolManager.setFeeGrowthOutside(
            stablePoolKey.toId(),
            tickLower,
            tickUpper,
            feeData.lowerFeeGrowthOutside0X128,
            feeData.upperFeeGrowthOutside0X128,
            feeData.lowerFeeGrowthOutside1X128,
            feeData.upperFeeGrowthOutside1X128
        );

        PositionInfo info = PositionInfoLibrary.initialize(stablePoolKey, tickLower, tickUpper);
        // When : calling getFeeAmounts()
        (uint256 fee0, uint256 fee1) = uniswapV4AM.getFeeAmounts(tokenId, stablePoolKey.toId(), info, liquidity);

        // Then : It should return the correct values, we can have rounding diff of max 1
        assertApproxEqAbs(feeData.desiredFee0, fee0, 1);
        assertApproxEqAbs(feeData.desiredFee1, fee1, 1);

        // And : Fees returned should always be lower or equal to expected fee (avoid reverting transactions)
        assertLe(fee0, feeData.desiredFee0);
        assertLe(fee1, feeData.desiredFee1);
    }

    function testFuzz_success_getFeeAmounts_outOfRangeLeft(
        FeeGrowth memory feeData,
        uint128 liquidity,
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper
    ) public {
        // Given : Liquidity is > 0
        vm.assume(liquidity > 0);

        // And : Positive fee
        feeData.desiredFee0 = bound(feeData.desiredFee0, 1, type(uint128).max);
        feeData.desiredFee1 = bound(feeData.desiredFee1, 1, type(uint128).max);

        // And : Calculate expected feeGrowth difference in order to obtain desired fee
        // (fee * Q128) / liquidity = diff in Q128.
        uint256 feeGrowthDiff0X128 = feeData.desiredFee0.mulDivDown(FixedPoint128.Q128, liquidity);

        feeData.lowerFeeGrowthOutside0X128 =
            bound(feeData.upperFeeGrowthOutside0X128, 0, type(uint256).max - feeGrowthDiff0X128);
        feeData.upperFeeGrowthOutside0X128 = feeData.lowerFeeGrowthOutside0X128 + feeGrowthDiff0X128;

        uint256 feeGrowthDiff1X128 = feeData.desiredFee1.mulDivDown(FixedPoint128.Q128, liquidity);

        feeData.lowerFeeGrowthOutside1X128 =
            bound(feeData.lowerFeeGrowthOutside1X128, 0, type(uint256).max - feeGrowthDiff1X128);
        feeData.upperFeeGrowthOutside1X128 = feeData.lowerFeeGrowthOutside1X128 + feeGrowthDiff1X128;

        {
            // And : Current tick should be > upper tick
            (, int24 currentTick,,) = stateView.getSlot0(stablePoolKey.toId());
            tickUpper = int24(bound(tickUpper, MIN_TICK + 2, currentTick - 1));
            tickLower = int24(bound(tickLower, MIN_TICK, tickUpper - 1));

            // And : Position is set
            bytes32 positionKey =
                keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
            poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
            positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);
        }

        // And : Valid pool state
        poolManager.setFeeGrowthOutside(
            stablePoolKey.toId(),
            tickLower,
            tickUpper,
            feeData.lowerFeeGrowthOutside0X128,
            feeData.upperFeeGrowthOutside0X128,
            feeData.lowerFeeGrowthOutside1X128,
            feeData.upperFeeGrowthOutside1X128
        );

        PositionInfo info = PositionInfoLibrary.initialize(stablePoolKey, tickLower, tickUpper);
        // When : calling getFeeAmounts()
        (uint256 fee0, uint256 fee1) = uniswapV4AM.getFeeAmounts(tokenId, stablePoolKey.toId(), info, liquidity);

        // Then : It should return the correct values, we can have rounding diff of max 1
        assertApproxEqAbs(feeData.desiredFee0, fee0, 1);
        assertApproxEqAbs(feeData.desiredFee1, fee1, 1);

        // And : Fees returned should always be lower or equal to expected fee (avoid reverting transactions)
        assertLe(fee0, feeData.desiredFee0);
        assertLe(fee1, feeData.desiredFee1);
    }

    function testFuzz_success_getFeeAmounts_positionInRange(
        FeeGrowth memory feeData,
        uint128 liquidity,
        uint96 tokenId,
        int24 tickLower,
        int24 tickUpper
    ) public {
        // Given : Liquidity is > 0
        vm.assume(liquidity > 0);

        // And : Positive fee
        feeData.desiredFee0 = bound(feeData.desiredFee0, 1, type(uint128).max);
        feeData.desiredFee1 = bound(feeData.desiredFee1, 1, type(uint128).max);

        // And : Calculate expected feeGrowth difference in order to obtain desired fee
        // (fee * Q128) / liquidity = diff in Q128.
        // As fee amount is calculated based on deducting feeGrowthOutside from feeGrowthGlobal,
        // no need to test with fuzzed feeGrowthOutside values as no risk of potential rounding errors (we're not testing UniV4 contracts).
        uint256 feeGrowthDiff0X128 = feeData.desiredFee0.mulDivDown(FixedPoint128.Q128, liquidity);

        feeData.feeGrowthGlobal0X128 = feeGrowthDiff0X128;

        uint256 feeGrowthDiff1X128 = feeData.desiredFee1.mulDivDown(FixedPoint128.Q128, liquidity);

        feeData.feeGrowthGlobal1X128 = feeGrowthDiff1X128;

        {
            // And : Position should be in range
            (, int24 currentTick,,) = stateView.getSlot0(stablePoolKey.toId());
            tickLower = int24(bound(tickLower, MIN_TICK, currentTick - 1));
            tickUpper = int24(bound(tickUpper, currentTick + 1, MAX_TICK));

            // And : Position is set
            bytes32 positionKey =
                keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(uint256(tokenId))));
            poolManager.setPositionLiquidity(stablePoolKey.toId(), positionKey, liquidity);
            positionManager.setPosition(users.owner, stablePoolKey, tickLower, tickUpper, tokenId);
        }

        // And : Valid pool state
        poolManager.setFeeGrowthGlobal(stablePoolKey.toId(), feeData.feeGrowthGlobal0X128, feeData.feeGrowthGlobal1X128);

        PositionInfo info = PositionInfoLibrary.initialize(stablePoolKey, tickLower, tickUpper);
        // When : calling getFeeAmounts()
        (uint256 fee0, uint256 fee1) = uniswapV4AM.getFeeAmounts(tokenId, stablePoolKey.toId(), info, liquidity);

        // Then : It should return the correct values, we can have rounding diff of max 1
        assertApproxEqAbs(feeData.desiredFee0, fee0, 1);
        assertApproxEqAbs(feeData.desiredFee1, fee1, 1);

        // And : Fees returned should always be lower or equal to expected fee (avoid reverting transactions)
        assertLe(fee0, feeData.desiredFee0);
        assertLe(fee1, feeData.desiredFee1);
    }
}
