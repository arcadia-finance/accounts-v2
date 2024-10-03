/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Test } from "../../../Base.t.sol";
import { BaseHook } from "../../../../lib/v4-periphery-fork/src/base/hooks/BaseHook.sol";
import { ERC20 } from "../../../../lib/solmate/src/tokens/ERC20.sol";
import { Fuzz_Test } from "../../Fuzz.t.sol";
import { FixedPointMathLib } from "../../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { Hooks } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/Hooks.sol";
import { LiquidityAmounts } from "../../../../src/asset-modules/UniswapV4/libraries/LiquidityAmountsV4.sol";
import { PoolManager } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/PoolManager.sol";
import { PoolKey } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/types/PoolKey.sol";
import { PositionManager } from "../../../../lib/v4-periphery-fork/src/PositionManager.sol";
import { StateView } from "../../../../lib/v4-periphery-fork/src/lens/StateView.sol";
import { TickMath } from "../../../../lib/v4-periphery-fork/lib/v4-core/src/libraries/TickMath.sol";
import { UniswapV4AMExtension } from "../../../../test/utils/extensions/UniswapV4AMExtension.sol";
import { UniswapV4Fixture } from "../../../utils/fixtures/uniswap-v4/UniswapV4Fixture.f.sol";

/**
 * @notice Common logic needed by all "UniswapV4AM" fuzz tests.
 */
abstract contract UniswapV4AM_Fuzz_Test is Fuzz_Test, UniswapV4Fixture {
    /* ///////////////////////////////////////////////////////////////
                              CONSTANTS
    /////////////////////////////////////////////////////////////// */

    UniswapV4AMExtension internal uniswapV4AM;
    PoolKey internal stablePoolKey;
    PoolKey internal randomPoolKey;

    ERC20 token0;
    ERC20 token1;

    uint256 internal constant INT256_MAX = 2 ** 255 - 1;
    // While the true minimum value of an int256 is 2 ** 255, Solidity overflows on a negation (since INT256_MAX is one less).
    // -> This true minimum value will overflow and revert.
    uint256 internal constant INT256_MIN = 2 ** 255 - 1;

    /* ///////////////////////////////////////////////////////////////
                              VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct TestVariables {
        uint256 decimals0;
        uint256 decimals1;
        uint256 amount0;
        uint256 amount1;
        int24 tickLower;
        int24 tickUpper;
        uint64 priceToken0;
        uint64 priceToken1;
        uint80 liquidity;
    }

    struct UnderlyingAssetState {
        uint256 decimals;
        uint256 usdValue;
    }

    struct FeeGrowth {
        uint256 desiredFee0;
        uint256 desiredFee1;
        uint256 lowerFeeGrowthOutside0X128;
        uint256 upperFeeGrowthOutside0X128;
        uint256 lowerFeeGrowthOutside1X128;
        uint256 upperFeeGrowthOutside1X128;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
    }

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Test, UniswapV4Fixture) {
        Fuzz_Test.setUp();
        // Deploy fixture for UniswapV4
        vm.startPrank(users.owner);
        UniswapV4Fixture.setUp();
        vm.stopPrank();

        // Initializes a pool
        stablePoolKey = initializePool(
            address(mockERC20.stable1),
            address(mockERC20.stable2),
            TickMath.getSqrtPriceAtTick(0),
            address(validHook),
            500,
            1
        );

        // Deploy Asset-Module
        vm.startPrank(users.owner);
        uniswapV4AM = new UniswapV4AMExtension(address(registry), address(positionManager), address(stateView));
        registry.addAssetModule(address(uniswapV4AM));
        uniswapV4AM.setProtocol();
        vm.stopPrank();
    }

    /*////////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    ////////////////////////////////////////////////////////////////*/

    function calculateAndValidateRangeTickCurrent(uint256 priceToken0, uint256 priceToken1)
        internal
        pure
        returns (uint256 sqrtPriceX96)
    {
        // Avoid divide by 0, which is already checked in earlier in function.
        vm.assume(priceToken1 > 0);
        // Function will overFlow, not realistic.
        vm.assume(priceToken0 <= type(uint256).max / 10 ** 28);
        vm.assume(priceToken1 <= type(uint256).max / 10 ** 18);
        // Cast to uint160 will overflow, not realistic.
        vm.assume(priceToken0 / priceToken1 < 2 ** 128);

        // sqrtPriceX96 must be within ranges, or TickMath reverts.
        uint256 priceXd28 = priceToken0 * 1e28 / priceToken1;
        uint256 sqrtPriceXd14 = FixedPointMathLib.sqrt(priceXd28);
        sqrtPriceX96 = sqrtPriceXd14 * 2 ** 96 / 1e14;
        vm.assume(sqrtPriceX96 >= MIN_SQRT_PRICE);
        vm.assume(sqrtPriceX96 <= MAX_SQRT_PRICE);
    }

    function givenValidTicks(int24 tickLower, int24 tickUpper)
        public
        view
        returns (int24 tickLower_, int24 tickUpper_)
    {
        tickLower_ = int24(bound(tickLower, MIN_TICK, MAX_TICK - 2));
        tickUpper_ = int24(bound(tickUpper, tickLower_ + 1, MAX_TICK));
    }

    // From UniV4-core tests
    function getLiquidityDeltaFromAmounts(int24 tickLower, int24 tickUpper, uint160 sqrtPriceX96)
        public
        pure
        returns (uint256 liquidityMaxByAmount)
    {
        // First get the maximum amount0 and maximum amount1 that can be deposited at this range.
        (uint256 maxAmount0, uint256 maxAmount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            uint128(type(int128).max)
        );

        // Compare the max amounts (defined by the range of the position) to the max amount constrained by the type container.
        // The true maximum should be the minimum of the two.
        // (ie If the position range allows a deposit of more then int128.max in any token, then here we cap it at int128.max.)

        uint256 amount0 = uint256(type(uint128).max / 2);
        uint256 amount1 = uint256(type(uint128).max / 2);

        maxAmount0 = maxAmount0 > amount0 ? amount0 : maxAmount0;
        maxAmount1 = maxAmount1 > amount1 ? amount1 : maxAmount1;

        liquidityMaxByAmount = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            maxAmount0,
            maxAmount1
        );
    }

    function givenValidPosition(
        uint256 liquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 priceToken0,
        uint256 priceToken1,
        uint8 outOfRange
    ) public returns (uint256 tokenId, uint256 amount0, uint256 amount1, bytes32 positionKey) {
        // Given : Calculate and check that tick current is within allowed ranges.
        uint160 sqrtPriceX96 = uint160(calculateAndValidateRangeTickCurrent(priceToken0, priceToken1));
        int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        vm.assume(isWithinAllowedRange(currentTick));

        // And : Valid ticks
        if (outOfRange == 1) {
            // Position should be fully in token 1
            vm.assume(currentTick > MIN_TICK + 2);
            tickUpper = int24(bound(tickUpper, MIN_TICK + 2, currentTick));
            tickLower = int24(bound(tickLower, MIN_TICK, tickUpper - 1));
        } else if (outOfRange == 2) {
            // Position should be fully in token 0
            vm.assume(currentTick < MAX_TICK - 2);
            tickLower = int24(bound(tickLower, currentTick + 1, MAX_TICK - 2));
            tickUpper = int24(bound(tickUpper, tickLower + 1, MAX_TICK));
        } else {
            // Ticks between min and max tick
            (tickLower, tickUpper) = givenValidTicks(tickLower, tickUpper);
        }

        {
            // And : Liquidity is within range
            uint256 maxLiquidity = getLiquidityDeltaFromAmounts(tickLower, tickUpper, sqrtPriceX96);
            liquidity = bound(liquidity, 1, maxLiquidity);
            vm.assume(liquidity <= poolManager.getTickSpacingToMaxLiquidityPerTick(1));
        }

        // Create Uniswap V4 pool initiated at tickCurrent with fee 500 and tickSpacing 1.
        randomPoolKey = initializePool(address(token0), address(token1), sqrtPriceX96, address(validHook), 500, 1);

        // And : Liquidity position is minted.
        tokenId = mintPosition(
            randomPoolKey,
            tickLower,
            tickUpper,
            liquidity,
            type(uint128).max,
            type(uint128).max,
            users.liquidityProvider
        );

        // Calculate amounts of underlying tokens.
        // We do not use the fuzzed liquidity, but fetch liquidity from the contract.
        // This is because there might be some small differences due to rounding errors.
        positionKey = keccak256(abi.encodePacked(address(positionManager), tickLower, tickUpper, bytes32(tokenId)));
        uint128 liquidity_ = stateView.getPositionLiquidity(randomPoolKey.toId(), positionKey);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity_
        );
    }
}
