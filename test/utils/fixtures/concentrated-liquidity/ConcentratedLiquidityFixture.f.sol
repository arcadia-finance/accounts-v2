/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Test } from "../../../../lib/forge-std/src/Test.sol";
import { TickMath } from "../../../../src/asset-modules/UniswapV3/libraries/TickMath.sol";

// forge-lint: disable-next-item(unsafe-typecast)
abstract contract ConcentratedLiquidityFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    // The maximum priceToken0 / priceToken1 ratio for which sqrtPriceX96 stays below TickMath.MAX_SQRT_RATIO.
    uint256 internal constant MAX_PRICE_RATIO = (uint256(TickMath.MAX_SQRT_RATIO) * 1e14 / 2 ** 96) ** 2 / 1e28;

    /*//////////////////////////////////////////////////////////////////////////
                                HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function givenValidPrices(uint256 priceToken0, uint256 priceToken1)
        public
        pure
        returns (uint256 priceToken0_, uint256 priceToken1_)
    {
        // Avoid divide by 0, which is already checked in earlier in function.
        priceToken1_ = bound(priceToken1, 1, type(uint256).max / 10 ** 18);
        // Function will overFlow, not realistic.
        uint256 maxPriceToken0 = type(uint256).max / 10 ** 28;
        // Cast to uint160 will overflow, not realistic.
        if (priceToken1_ < 2 ** 128) {
            uint256 maxRatio = priceToken1_ * MAX_PRICE_RATIO;
            if (maxRatio < maxPriceToken0) maxPriceToken0 = maxRatio;
        }
        // A priceXd28 of 0 puts sqrtPriceX96 below the minimum.
        priceToken0_ = bound(priceToken0, (priceToken1_ - 1) / 10 ** 28 + 1, maxPriceToken0);
    }

    function givenValidExposures(
        uint256 amount,
        uint112 initialExposure,
        uint112 maxExposure,
        uint256 price,
        uint256 maxUsdValue
    ) public pure returns (uint112 initialExposure_, uint112 maxExposure_) {
        // Usd value of the underlying asset does not overflow.
        uint256 maxAmount = maxUsdValue / price / 10 ** 18;
        vm.assume(amount < type(uint112).max);
        vm.assume(amount < maxAmount);

        // Exposure to the underlying asset stays below maxExposure.
        maxExposure_ = uint112(bound(maxExposure, amount + 1, type(uint112).max));

        uint256 exposureLimit = maxExposure_ - amount - 1;
        uint256 usdLimit = maxAmount - amount - 1;
        initialExposure_ = uint112(bound(initialExposure, 0, exposureLimit < usdLimit ? exposureLimit : usdLimit));
    }

    function givenValidTicks(int24 tickLower, int24 tickUpper)
        public
        pure
        returns (int24 tickLower_, int24 tickUpper_)
    {
        tickLower_ = int24(bound(tickLower, TickMath.MIN_TICK, TickMath.MAX_TICK - 2));
        tickUpper_ = int24(bound(tickUpper, tickLower_ + 1, TickMath.MAX_TICK));
    }

    function isWithinAllowedRange(int24 tick) internal pure returns (bool) {
        return (tick < 0 ? uint256(-int256(tick)) : uint256(int256(tick))) <= uint256(uint24(TickMath.MAX_TICK));
    }
}
